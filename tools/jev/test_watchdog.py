import unittest

from jogar import pending_stop_requires_termination


class StopHandshakeTests(unittest.TestCase):
    def test_victory_leaves_time_for_final_capture_and_stop(self):
        self.assertFalse(pending_stop_requires_termination("implemented_story_completed", False, 0.25))
        self.assertFalse(pending_stop_requires_termination("implemented_story_completed", True, 15))

    def test_unresponsive_process_is_still_bounded(self):
        self.assertTrue(pending_stop_requires_termination("implemented_story_completed", False, 10))
        self.assertFalse(pending_stop_requires_termination("", False, 30))
