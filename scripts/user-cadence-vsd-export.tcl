# Native VSD 5.6.7 reader/filter/snapshot APIs, with time-origin alignment only.
# Set CATALYST_CADENCE_ANALYSIS to analyze-user-cadence.py's experiment directory.
source [file join [file dirname [info script]] user-vsd-export.tcl]
after cancel catalystExport

proc cadenceGraph {name title series yTitle maximum logScale} {
    global vsd env cadenceCases cadenceData cadenceLabels cadenceColors cadenceIdleEnd cadenceBurstEnd
    set vsd(curchart) $name
    set window [createGraphWindow $name]; set graph $window.graph
    set index 0
    foreach spec $cadenceCases {
        set label [lindex $spec 0]
        lassign $cadenceData($label,$series) x y
        if {[llength $x] < 2} {error "Missing chart points: $label/$series"}
        set color [lindex $cadenceColors $index]
        $graph element create case$index -xdata $x -ydata $y -mapy y -color $color \
            -label [lindex $cadenceLabels $index] -linewidth 2 -symbol none -smooth step
        if {$series eq {rtt}} {$graph element configure case$index -symbol circle -pixels 2 -linewidth 0}
        incr index
    }
    $graph configure -title $title -font {Helvetica 17} -background white -plotbackground white \
        -leftmargin 110 -rightmargin 75 -topmargin 50 -bottommargin 110
    foreach axis {x y y2} {$graph axis configure $axis -tickfont {Helvetica 12} -titlefont {Helvetica 13} -background white}
    set idle [string match idle* $series]
    $graph xaxis configure -command catalystTicks -title [expr {$idle ? {Seconds since conservative idle-window start} : {Seconds since first burst's first submission}}] \
        -min 0 -max [expr {$idle ? $cadenceIdleEnd : $cadenceBurstEnd}]
    $graph yaxis configure -title $yTitle -min [expr {$logScale ? 1 : 0}] -logscale $logScale
    if {$maximum ne {}} {$graph yaxis configure -max $maximum}
    $graph legend configure -font {Helvetica 12} -position bottom -anchor w -background white
    wm geometry $window 1500x850+0+0
    update
    showAxis $graph yaxis
    $graph yaxis configure -showticks 1 -background white
    update idletasks
    set photo [image create photo]; $graph snap $photo
    $photo write [file join $env(CATALYST_CADENCE_ANALYSIS) "$name.png"] -format png
    image delete $photo
}

proc cadenceExport {} {
    global vsd env catalystSeries catalystMetadata catalystExported
    global cadenceCases cadenceData cadenceLabels cadenceColors cadenceIdleEnd cadenceBurstEnd
    if {[catch {
        source [file join $env(CATALYST_CADENCE_ANALYSIS) chart-cases.tcl]
        set cadenceLabels {}
        foreach spec $cadenceCases {lappend cadenceLabels [lindex $spec 12]}
        set cadenceColors {#475467 #175cd3 #039855 #b54708 #98a2b3}
        set cadenceIdleEnd 1e30; set cadenceBurstEnd 0
        set vsd(singleFileMode) 1; set vsd(appendMode) 0
        set vsd(def:showgridlines) 1; set vsd(def:showlinestats) 0
        foreach spec $cadenceCases {
            lassign $spec name path appPid controlPid stonePid appFirst controlFirst stoneFirst burstStart burstEnd idleStart idleEnd
            setDataFile $path
            array unset catalystExported
            set catalystSeries [open [file join $env(CATALYST_CADENCE_ANALYSIS) "$name-vsd-series.tsv"] w]
            set catalystMetadata [open [file join $env(CATALYST_CADENCE_ANALYSIS) "$name-vsd-metadata.txt"] w]
            puts $catalystSeries "type\tpid\tstat\tfilter\txMillis\ty"
            foreach definition [list [list app Gem $appPid CommitCount $appFirst] \
                [list control Gem $controlPid CommitCount $controlFirst] \
                [list sync Stn $stonePid StnAioTimeInFsyncMs $stoneFirst] \
                [list commitWait Gem $appPid TimeStoneCommit $appFirst]] {
                lassign $definition tag type pid stat firstRaw
                set line [catalystLine $type $pid $stat persecond]
                set info [$line -info]; set xv [lindex $info 2]; set yv [lindex $info 3]
                set times [$xv range 0 end]; set values [$yv range 0 end]
                set shift [expr {$firstRaw - round([lindex $times 0]*1000)}]
                foreach phase [list [list idle $idleStart $idleEnd] [list burst $burstStart $burstEnd]] {
                    lassign $phase phaseName start end
                    set x {}; set y {}; set previous {}
                    foreach time $times value $values {
                        set wall [expr {round($time*1000)+$shift}]
                        # A rate point describes its preceding interval. Exclude boundary intervals.
                        if {$previous ne {} && $previous >= $start && $wall <= $end} {
                            lappend x [expr {($wall-$start)/1000.0}]; lappend y $value
                        }
                        set previous $wall
                    }
                    set cadenceData($name,$phaseName-$tag) [list $x $y]
                }
            }
            close $catalystSeries; close $catalystMetadata
            set cadenceIdleEnd [expr {min($cadenceIdleEnd,($idleEnd-$idleStart)/1000.0)}]
            set cadenceBurstEnd [expr {max($cadenceBurstEnd,($burstEnd-$burstStart)/1000.0)}]
        }
        set fd [open [file join $env(CATALYST_CADENCE_ANALYSIS) writer-first-burst.tsv]]
        gets $fd
        foreach spec $cadenceCases {set cadenceData([lindex $spec 0],rtt) [list {} {}]}
        while {[gets $fd row] >= 0} {
            lassign [split $row \t] name time value
            lassign $cadenceData($name,rtt) x y
            lappend x $time; lappend y $value; set cadenceData($name,rtt) [list $x $y]
        }
        close $fd
        set fd [open [file join $env(CATALYST_CADENCE_ANALYSIS) vsd-chart-series.tsv] w]
        puts $fd "case\tseries\txMillis\ty"
        foreach spec $cadenceCases {
            set name [lindex $spec 0]
            foreach series {idle-app idle-control burst-app burst-sync rtt} {
                lassign $cadenceData($name,$series) x y
                foreach time $x value $y {puts $fd [join [list $name $series $time $value] \t]}
            }
        }
        close $fd
        cadenceGraph vsd-idle-application {Idle Users: application Gem commit rate under the configured cadences} idle-app {Native commits/s (actual sample intervals)} {} 0
        cadenceGraph vsd-idle-control {Idle Users: control Gem commit rate under the configured cadences} idle-control {Native commits/s (actual sample intervals)} {} 0
        cadenceGraph vsd-burst-commits {First burst: application Gem commit rate (elapsed time is not rescaled)} burst-app {Native commits/s (actual sample intervals)} {} 0
        cadenceGraph vsd-burst-sync {First burst: Stone log-sync time (shared cache, overlapping counters)} burst-sync {Native log-sync milliseconds/s} {} 0
        cadenceGraph vsd-writer-rtt {First burst: external writer RTT at completion (log scale)} rtt {External writer round-trip milliseconds (log scale)} {} 1
        puts CADENCE_VSD_GRAPHS_EXPORTED
    } message]} {puts stderr $message; exit 1}
    exit 0
}
after 2000 cadenceExport
