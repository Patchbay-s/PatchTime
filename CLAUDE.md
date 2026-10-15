# Project guidelines

- Keep the public product name PatchTime. Do not change existing bundle,
  CloudKit, or App Group identifiers without an explicit migration plan.
- Keep credentials, signing identities, and machine-specific settings out of
  source control. Use the documented local Xcode configuration example.
- Run the generic iOS Xcode build and relevant package or project checks before
  submitting changes. Do not require a simulator for routine validation.
- Keep sample records synthetic and avoid committing screenshots of personal
  work, payroll, or account data.
