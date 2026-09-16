import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("guard", Path(__file__).parents[1] / "check_private_swipe.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class PrivateSwipeGuardTests(unittest.TestCase):
    def test_private_requires_debug_isolation_and_never_archive(self):
        env = dict(CONFIGURATION="PrivateSwipe", SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG NUMPAD_PRIVATE_SWIPE",
                   PRODUCT_BUNDLE_IDENTIFIER="com.morevoltage.NumPad.PrivateSwipe", ACTION="build")
        self.assertTrue(guard.check_environment(env))
        for change in ({"ACTION": "install"}, {"CONFIGURATION": "Release"},
                       {"SWIFT_ACTIVE_COMPILATION_CONDITIONS": "NUMPAD_PRIVATE_SWIPE"},
                       {"PRODUCT_BUNDLE_IDENTIFIER": "com.morevoltage.NumPad"},
                       {"SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"}):
            with self.assertRaises(ValueError):
                guard.check_environment(dict(env, **change))

    def test_production_release_archive_allowed(self):
        self.assertFalse(guard.check_environment(dict(CONFIGURATION="Release", ACTION="install",
                         PRODUCT_BUNDLE_IDENTIFIER="com.morevoltage.NumPad")))

    def test_other_swift_flags_cannot_smuggle_private_into_release(self):
        with self.assertRaises(ValueError):
            guard.check_environment(dict(CONFIGURATION="Release", ACTION="install",
                                         OTHER_SWIFT_FLAGS="-DNUMPAD_PRIVATE_SWIPE"))

    def test_embedded_extension_binary_and_swipe_resource_are_checked(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / "NumPad.app"
            extension = app / "PlugIns" / "Keyboard.appex"
            extension.mkdir(parents=True)
            for bundle in (app, extension):
                (bundle / "Info.plist").write_bytes(plistlib.dumps(dict(CFBundleExecutable="binary",
                            CFBundleIdentifier="com.morevoltage.NumPad")))
                (bundle / "binary").write_bytes(b"production executable")
            guard.check_product(app)
            (extension / "binary").write_bytes(b"stripped Swift symbol QwertyGlideDecoder suffix")
            with self.assertRaises(ValueError):
                guard.check_product(app)
            (extension / "binary").write_bytes(b"production executable")
            (app / "swipe-vocabulary.dat").write_bytes(b"words")
            with self.assertRaises(ValueError):
                guard.check_product(app)

    def test_private_bundle_rejected_even_without_symbols(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / "NumPad.app"
            app.mkdir()
            (app / "Info.plist").write_bytes(plistlib.dumps(dict(CFBundleExecutable="binary",
                        CFBundleIdentifier="com.morevoltage.NumPad.PrivateSwipe")))
            (app / "binary").write_bytes(b"stripped")
            with self.assertRaises(ValueError):
                guard.check_product(app)


if __name__ == "__main__":
    unittest.main()
