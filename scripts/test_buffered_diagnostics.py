import json
from pathlib import Path
import tempfile
import unittest
from buffered_user_diagnostics import validate_buffered_diagnostics


class BufferedDiagnostics(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.base=Path(self.temp.name);(self.base/'profile').mkdir()
        self.export=dict(completed=True,mode='buffered',ownerProcessVerified=True,failure=None,
            sampleCount=2,maximumSamples=3600,startupSkips=[],sampleAttempts=2,skippedNativeBusy=0,exportStartedMillis=1000,exportFinishedMillis=1005)
        self.profiles=[dict(directory='profile',slowConsumers=2,diagnosticWindow=dict(startMillis=0,endMillis=900,stalledStartMillis=500,stalledEndMillis=800))]
        self.samples=[dict(sample=i,millis=t,snapshotStartedMillis=t,snapshotFinishedMillis=t+1,hookFinishedMillis=t+2,
            feeds=[dict(pending=3,watched=3,publisher=True)]*2,publishers=2,native={'1':4,'8':400},
            connectStatistics=dict(callPeak=12,copyPeak=400),driveLimits=dict(calls=128,bytes=65536,millis=5)) for i,t in [(1,100),(2,600)]]
        self.timings=dict(worker='worker',rows=[dict(sequence=1,localTimings=dict(outerCommitStartedMillis=10,
            outerCommitFinishedMillis=20,outerCommitOutcome='committed',resultFinalizationStartedMillis=21,
            resultFinalizationFinishedMillis=22,resultFinalizationOutcome='returned'))],lastSequence=1,maximumRows=50000)
    def run_capture(self):
        (self.base/'sampler-export.json').write_text(json.dumps(self.export))
        for sample in self.samples:(self.base/f"native-{sample['sample']}.json").write_text(json.dumps(sample))
        (self.base/'worker-local-timings.json').write_text(json.dumps(self.timings))
        return validate_buffered_diagnostics(self.base,self.profiles)
    def test_checks_capacity_and_stalled_retention_after_export(self):
        result=self.run_capture()
        self.assertTrue(result['exportAfterTimedWorkload'])
        self.assertEqual(self.profiles[0]['slowFeedsRetainingStateAfterHealthyConvergence'],2)
        self.assertEqual(self.profiles[0]['nativeSampleRange'],[1,2])
        self.assertEqual(result['snapshotMillis']['max'],2)
        self.assertTrue((self.base/'profile/stalled-server.json').exists())
    def test_missing_sample_fails(self):
        self.samples.pop()
        with self.assertRaisesRegex(ValueError,'Missing'):self.run_capture()
    def test_export_during_workload_fails(self):
        self.export['exportStartedMillis']=800
        with self.assertRaisesRegex(ValueError,'before the timed'):self.run_capture()
    def test_capacity_overflow_fails(self):
        self.samples[1]['feeds'][0]['pending']=4
        with self.assertRaisesRegex(ValueError,'Unbounded feed'):self.run_capture()
    def test_missing_stalled_window_is_not_accepted(self):
        self.profiles[0]['diagnosticWindow']['stalledStartMillis']=700
        with self.assertRaisesRegex(ValueError,'No diagnostic snapshot'):self.run_capture()
    def test_retention_evidence_cannot_be_omitted(self):
        self.samples[1]['feeds']=[dict(pending=0,watched=3,publisher=True)]*2
        with self.assertRaisesRegex(ValueError,'retention evidence'):self.run_capture()
    def test_failed_export_and_owner_are_rejected(self):
        self.export['failure']='buffer exhausted'
        with self.assertRaisesRegex(ValueError,'export failed'):self.run_capture()
        self.export.update(failure=None,ownerProcessVerified=False)
        with self.assertRaisesRegex(ValueError,'export failed'):self.run_capture()
    def test_startup_skips_must_precede_timed_workload(self):
        self.export.update(startupSkips=[[-100,'Users service not installed']],sampleAttempts=3)
        self.assertTrue(self.run_capture()['exportAfterTimedWorkload'])
        self.export['startupSkips']=[[100,'Users service not installed']]
        with self.assertRaisesRegex(ValueError,'during timed workload'):self.run_capture()
    def test_dropped_snapshot_attempt_is_rejected(self):
        self.export['sampleAttempts']=3
        with self.assertRaisesRegex(ValueError,'attempt accounting'):self.run_capture()
    def test_invalid_sample_time_is_rejected(self):
        self.samples[1]['snapshotFinishedMillis']=599
        with self.assertRaisesRegex(ValueError,'snapshot timing'):self.run_capture()
    def test_local_timing_gap_is_rejected(self):
        self.timings['rows'][0]['sequence']=2
        with self.assertRaisesRegex(ValueError,'timing sequence gap'):self.run_capture()
    def test_premature_finalization_is_rejected(self):
        self.timings['rows'][0]['localTimings']['resultFinalizationStartedMillis']=19
        with self.assertRaisesRegex(ValueError,'preceded outer commit'):self.run_capture()
    def test_incomplete_or_reversed_timing_is_rejected(self):
        self.timings['rows'][0]['localTimings'].pop('outerCommitOutcome')
        with self.assertRaisesRegex(ValueError,'Incomplete or reversed'):self.run_capture()


if __name__=='__main__':unittest.main()
