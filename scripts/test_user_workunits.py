import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('workunit_analysis', Path(__file__).with_name('analyze-user-workunits.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def observation(sequences=(1, 2), generation='launch'):
    return dict(recordCount=len(sequences), heads={'worker':dict(sequence=2, host='application', retentionLimit=5000, retained=2)},
                records=[dict(worker='worker', host='application', generation=generation, sequence=n,
                              completionRecordingOutcome='recorded', workUnitClass='CCQuicDriveWork', requiresTransaction=False,
                              transactionOutcome='inMemory', successful=True, durationMillis=1) for n in sequences])


class WorkunitAnalysisTests(unittest.TestCase):
    def test_nontransactional_body_still_counts_as_durable_completion(self):
        summary = module.summarize_records(observation())['worker']
        self.assertEqual(summary['nontransactionalCompletionCount'], 2)
        self.assertEqual(summary['classes'][0]['transactionOutcomes'], {'inMemory':2})
        self.assertEqual(summary['retentionLimit'], 5000)

    def test_gaps_duplicates_and_late_initial_snapshot_are_refused(self):
        for sequences in [(1, 1), (2,), (1, 3)]:
            with self.subTest(sequences=sequences), self.assertRaises(ValueError):
                module.summarize_records(observation(sequences))

    def test_generation_change_is_not_combined(self):
        data = observation()
        data['records'][1]['generation'] = 'different-launch'
        with self.assertRaises(ValueError): module.summarize_records(data)

    def test_pending_recording_is_not_declared_durable(self):
        data = observation()
        data['records'][1]['completionRecordingOutcome'] = 'pending'
        with self.assertRaises(ValueError): module.summarize_records(data)


if __name__ == '__main__': unittest.main()
