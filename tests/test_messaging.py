"""Static messaging schema checks; real authorization requires integration tests."""
import pathlib
import unittest

SQL = (pathlib.Path(__file__).resolve().parents[1] / 'supabase/migrations/202611060003_messaging.sql').read_text().lower()

class MessagingChecks(unittest.TestCase):
    def test_default_deny(self):
        for name in ('conversations', 'conversation_participants', 'messages', 'message_attachments'):
            with self.subTest(table=name):
                self.assertIn(f'alter table public.{name} enable row level security', SQL)
        self.assertIn('from anon, authenticated;', SQL)
        self.assertNotRegex(SQL, r'grant\s+.+?\s+to\s+(?:anon|authenticated)')

    def test_sender_membership_reference(self):
        self.assertIn('foreign key (conversation_id, sender_id) references public.conversation_participants(conversation_id, user_id)', SQL)

if __name__ == '__main__':
    unittest.main()
