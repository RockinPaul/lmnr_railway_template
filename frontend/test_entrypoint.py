"""Check auth startup guards without network services or real credentials.

The node stand-in records whether the real entrypoint reaches dependency/app startup.
Run: python3 -B -m unittest discover -s frontend -p 'test_*.py'
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class SignInGuardTest(unittest.TestCase):
    def probe(self, overrides, allowed):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            node = root / 'node'
            node.write_text('#!/bin/sh\nprintf "node reached\\n" >> "$TEST_NODE_LOG"\n')
            node.chmod(0o755)
            env = {k: v for k, v in os.environ.items()
                   if not k.startswith(('AUTH_', 'ALLOW_', 'FORCE_', 'BETTER_AUTH'))}
            env.update(PATH=str(root) + os.pathsep + env['PATH'],
                       DATABASE_URL='postgresql://fixture/no-network',
                       CLICKHOUSE_URL='http://fixture/no-network', CLICKHOUSE_PASSWORD='unused-fixture',
                       BACKEND_URL='http://fixture', BACKEND_RT_URL='http://fixture',
                       SHARED_SECRET_TOKEN='unused-fixture', AEAD_SECRET_KEY='a' * 64,
                       NEXTAUTH_URL='http://fixture', NEXTAUTH_SECRET='unused-fixture',
                       TEST_NODE_LOG=str(root / 'node.log'))
            env.update(overrides)
            result = subprocess.run(['sh', str(Path(__file__).with_name('entrypoint.sh'))],
                                    env=env, capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0 if allowed else 1, result.stdout + result.stderr)
            self.assertEqual((root / 'node.log').exists(), allowed, result.stdout + result.stderr)

    def test_provider_required_without_explicit_opt_in(self):
        self.probe({}, False)

    def test_configured_provider_starts(self):
        self.probe({'AUTH_GITHUB_ID': 'fixture', 'AUTH_GITHUB_SECRET': 'unused-fixture'}, True)

    def test_forced_email_cannot_hide_behind_configured_provider(self):
        self.probe({'AUTH_GITHUB_ID': 'fixture', 'AUTH_GITHUB_SECRET': 'unused-fixture',
                    'FORCE_EMAIL_AUTH': 'true'}, False)

    def test_forced_email_requires_explicit_risk_acceptance(self):
        self.probe({'AUTH_GITHUB_ID': 'fixture', 'AUTH_GITHUB_SECRET': 'unused-fixture',
                    'FORCE_EMAIL_AUTH': 'true', 'ALLOW_PASSWORDLESS_SIGNIN': 'true'}, True)

    def test_test_only_passwordless_opt_in_starts(self):
        self.probe({'ALLOW_PASSWORDLESS_SIGNIN': 'true'}, True)


if __name__ == '__main__':
    unittest.main()
