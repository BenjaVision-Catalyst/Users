# Source from a fresh VSDHOME/.vsdconfig with VSD 5.6.7.
# Uses VSD's native reader, filtered vectors, chart creation and snapshot engine.
# External writer RTT is labeled explicitly. No personal settings are modified.
proc catalystTicks {widget value} {return [format %.1f [expr {$value / 1000.0}]]}

proc catalystLine {type pid stat filter} {
    global catalystSeries catalystMetadata catalystExported
    set selected {}; set maximum 0
    foreach instance [sl_stat -enabledobjinstances [list $type]] {
        if {[lindex [lindex $instance 0] 1] != $pid} {continue}
        set line [sl_create -line [list [lindex $instance 6]] $stat $filter 0 $stat]
        set count [lindex [$line -stats {} {}] 0]
        if {$count > $maximum} {
            if {$selected ne {}} {$selected -free}
            set selected $line; set maximum $count
        } else {$line -free}
    }
    if {$selected eq {} || $maximum < 2} {error "Missing native series $type/$pid/$stat"}
    set key "$type/$pid/$stat/$filter"
    if {![info exists catalystExported($key)]} {
        set catalystExported($key) 1
        set info [$selected -info]
        puts $catalystMetadata [list $key $info [sl_stat -info $stat]]
        set xv [lindex $info 2]; set yv [lindex $info 3]
        foreach x [$xv range 0 end] y [$yv range 0 end] {
            puts $catalystSeries [join [list $type $pid $stat $filter $x $y] \t]
        }
    }
    return $selected
}

proc catalystGraph {name title specifications minimum maximum includeWriter gcMode {yTitle {Native milliseconds per recorded sample}} {yMaximum {}}} {
    global vsd env catalystSlowStart catalystSlowEnd
    set vsd(curchart) $name
    set window [createGraphWindow $name]
    set graph $window.graph
    foreach spec $specifications {
        lassign $spec type pid stat filter axis label color
        set line [catalystLine $type $pid $stat $filter]
        addLineToChart $line 0 0 $axis none
        # VSD slots are numeric; the newest slot has the greatest number.
        set element [lindex [lsort -integer [$graph element names]] end]
        $graph element configure $element -label $label -color $color -linewidth 2 -smooth step
    }
    if {$includeWriter} {
        set fd [open [file join $env(CATALYST_VSD_ANALYSIS) writer-x.txt]]; set x [read $fd]; close $fd
        set fd [open [file join $env(CATALYST_VSD_ANALYSIS) writer-y.txt]]; set y [read $fd]; close $fd
        $graph element create writerRTT -xdata $x -ydata $y -mapy y2 -color #b42318 \
            -label {Writer RTT at completion (external client, ms)} -symbol circle -pixels 3 -linewidth 0
        showAxis $graph y2axis
    }
    $graph configure -title $title -font {Helvetica 17} -background white -plotbackground white \
        -leftmargin 110 -rightmargin 110 -topmargin 50 -bottommargin 95
    foreach axis {x y y2} {$graph axis configure $axis -tickfont {Helvetica 12} -titlefont {Helvetica 13} -background white}
    $graph xaxis configure -command catalystTicks -title {Seconds since native capture start}
    $graph yaxis configure -title $yTitle -min 0
    if {$yMaximum ne {}} {$graph yaxis configure -max $yMaximum}
    $graph y2axis configure -title {Writer round-trip milliseconds} -min 0
    $graph legend configure -font {Helvetica 12} -position bottom -anchor w -background white
    if {$gcMode} {
        $graph yaxis configure -title {GC milliseconds per recorded sample} -max 1
        $graph y2axis configure -title {GC collections per recorded sample} -max 1
    }
    if {$name eq {vsd-steady}} {
        $graph yaxis configure -max 150
        $graph y2axis configure -max 150
    }
    if {$minimum ne {}} {$graph xaxis configure -min $minimum -max $maximum}
    if {$name in {vsd-pause vsd-gc}} {
        foreach time [list $catalystSlowStart $catalystSlowEnd] {
            $graph marker create line -coords [list $time -Inf $time Inf] \
                -outline #b42318 -dashes {5 5} -linewidth 1
        }
    }
    wm geometry $window 1500x850+0+0
    update
    # VSD's pending chart-selection callbacks may hide a reused native axis.
    showAxis $graph yaxis
    $graph yaxis configure -showticks 1 -background white
    update idletasks
    set photo [image create photo]
    $graph snap $photo
    $photo write [file join $env(CATALYST_VSD_ANALYSIS) "$name.png"] -format png
    image delete $photo
    # Keep chart windows alive until VSD exits; its chart registry owns them.
}

proc catalystExport {} {
    global vsd env catalystSeries catalystMetadata catalystStonePid catalystServingPid
    global catalystZoomStart catalystZoomEnd catalystSteadyStart catalystSteadyEnd
    global catalystSlowStart catalystSlowEnd
    if {[catch {
        source [file join $env(CATALYST_VSD_ANALYSIS) charts.tcl]
        setDataFile $env(CATALYST_VSD_CAPTURE)
        set vsd(def:showPidInLegend) 1
        set vsd(def:showlinestats) 0
        set vsd(def:showgridlines) 1
        set catalystSeries [open [file join $env(CATALYST_VSD_ANALYSIS) vsd-series.tsv] w]
        set catalystMetadata [open [file join $env(CATALYST_VSD_ANALYSIS) vsd-series-metadata.txt] w]
        puts $catalystSeries "type\tpid\tstat\tfilter\txMillis\ty"
        set waitSpecs [list \
            [list Stn $catalystStonePid StnAioTimeInFsyncMs persample y {Stone log-sync time} #c87010] \
            [list Gem $catalystServingPid TimeStoneCommit persample y {Serving Gem: Stone-commit time} #175cd3]]
        catalystGraph vsd-overview {Users: one and 60 observers - native commit waits and external RTT} $waitSpecs {} {} 1 0
        catalystGraph vsd-pause {60 observers: slow-request context - sample-boundary limited} $waitSpecs $catalystZoomStart $catalystZoomEnd 1 0
        catalystGraph vsd-steady {60 observers: selected steady second-burst window} $waitSpecs $catalystSteadyStart $catalystSteadyEnd 1 0
        set gcSpecs [list \
            [list Gem $catalystServingPid TimeInScavenges persample y {Scavenge time} #175cd3] \
            [list Gem $catalystServingPid TimeInMarkSweep persample y {Mark-sweep time} #c87010] \
            [list Gem $catalystServingPid ScavengeCount persample y2 {Scavenge collections} #039855] \
            [list Gem $catalystServingPid MarkSweepCount persample y2 {Mark-sweep collections} #b42318]]
        catalystGraph vsd-gc {Serving Gem: GC activity around the slow request} $gcSpecs $catalystZoomStart $catalystZoomEnd 0 1
        close $catalystSeries; close $catalystMetadata
        puts VSD_GRAPHS_EXPORTED
    } message]} {puts stderr $message; exit 1}
    exit 0
}
after 2000 catalystExport
