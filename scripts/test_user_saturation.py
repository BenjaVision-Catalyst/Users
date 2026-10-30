import copy
import unittest
from user_saturation import analyze_writer


class SaturationEvidenceTests(unittest.TestCase):
    def fixture(self):
        rows = []
        phases = []
        for offset, name in [(0, 'burstA.json'), (10, 'burstB.json')]:
            phases.append(dict(phase=name, startedAt=offset, finishedAt=offset+2,
                               requests=4, concurrency=2, peakActive=2, activeAtEnd=0))
            for i, (start, end) in enumerate([(.01,.8), (.51,.7), (1.01,1.8), (1.51,1.7)]):
                rows.append(dict(phase=name, ordinal=i, lane=i%2, user=str(i%2), revision=offset+i,
                                 offeredAt=offset+i*.5, sentAt=offset+start, replyAt=offset+end))
        return dict(count=8, writes=list(reversed(rows)), phases=phases)

    def test_completion_order_does_not_shorten_window(self):
        result = analyze_writer(self.fixture(), 500)
        self.assertAlmostEqual(result['phases'][0]['elapsedSeconds'], 1.79)
        self.assertEqual(result['phases'][0]['peakInFlight'], 2)
        self.assertEqual(result['phases'][0]['demandAtOfferedEnd']['outstandingDemand'], 2)

    def test_admission_lag_is_separate_from_inflight(self):
        value = self.fixture()
        for row in value['writes']:
            row['sentAt'] += .2; row['replyAt'] += .2
        result = analyze_writer(value, 500)['phases'][0]
        self.assertAlmostEqual(result['admissionLagMillis']['mean'], 210)
        self.assertEqual(result['maximumAdmissionBacklog'], 1)

    def test_incomplete_and_duplicate_evidence_refused(self):
        for mutation in [lambda x:x['writes'].pop(), lambda x:x['writes'][0].update(user=x['writes'][1]['user'], revision=x['writes'][1]['revision'])]:
            value = self.fixture(); mutation(value)
            with self.assertRaises(ValueError): analyze_writer(value, 500)

    def test_reversed_timing_wrong_schedule_and_peak_refused(self):
        for mutation in [lambda x:x['writes'][0].update(replyAt=0), lambda x:x['writes'][0].update(offeredAt=0), lambda x:x['phases'][0].update(peakActive=1)]:
            value = self.fixture(); mutation(value)
            with self.assertRaises(ValueError): analyze_writer(value, 500)


if __name__ == '__main__': unittest.main()
