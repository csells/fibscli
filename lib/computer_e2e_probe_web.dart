import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void installComputerE2eProbe(Map<String, Object?> Function() snapshot) {
  // ignore: do_not_use_environment -- read-only browser-test instrumentation
  const enabled = bool.fromEnvironment('computer_e2e_probe');
  if (!enabled) return;
  globalContext.setProperty(
    '__computerE2EState'.toJS,
    (() => snapshot().jsify()).toJS,
  );
}

void removeComputerE2eProbe() {
  // ignore: do_not_use_environment -- read-only browser-test instrumentation
  const enabled = bool.fromEnvironment('computer_e2e_probe');
  if (enabled) globalContext.delete('__computerE2EState'.toJS);
}
