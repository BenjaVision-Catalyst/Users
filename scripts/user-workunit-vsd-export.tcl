# Source from a fresh VSDHOME/.vsdconfig, using the same environment as
# user-vsd-export.tcl. workunit-charts.tcl supplies verified control PID and
# conservative idle-window boundaries from analyze-user-workunits.py.
source [file join [file dirname [info script]] user-vsd-export.tcl]
after cancel catalystExport

proc catalystWorkunitExport {} {
    global vsd env catalystSeries catalystMetadata catalystStonePid catalystServingPid
    global catalystControlPid catalystIdleStart catalystIdleEnd
    if {[catch {
        source [file join $env(CATALYST_VSD_ANALYSIS) charts.tcl]
        source [file join $env(CATALYST_VSD_ANALYSIS) workunit-charts.tcl]
        setDataFile $env(CATALYST_VSD_CAPTURE)
        set vsd(def:showPidInLegend) 1
        set vsd(def:showlinestats) 0
        set vsd(def:showgridlines) 1
        set catalystSeries [open [file join $env(CATALYST_VSD_ANALYSIS) vsd-workunit-series.tsv] w]
        set catalystMetadata [open [file join $env(CATALYST_VSD_ANALYSIS) vsd-workunit-series-metadata.txt] w]
        puts $catalystSeries "type\tpid\tstat\tfilter\txMillis\ty"
        set specs [list \
            [list Gem $catalystServingPid CommitCount persecond y {Application Gem commits/s} #175cd3] \
            [list Gem $catalystControlPid CommitCount persecond y {Control Gem commits/s} #039855] \
            [list Stn $catalystStonePid TotalCommits persecond y {Stone commits/s (shared cache)} #c87010]]
        catalystGraph vsd-commits {Users: native commit rates across setup, workload and cleanup} $specs {} {} 0 0 {Native commits per second (actual sample interval)}
        catalystGraph vsd-idle {60 observers: conservative final window with zero client application requests} $specs $catalystIdleStart $catalystIdleEnd 0 0 {Native commits per second (actual sample interval)} 100
        close $catalystSeries; close $catalystMetadata
        puts VSD_WORKUNIT_GRAPHS_EXPORTED
    } message]} {puts stderr $message; exit 1}
    exit 0
}
after 2000 catalystWorkunitExport
