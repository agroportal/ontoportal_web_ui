# frozen_string_literal: true

# Lift Regexp.timeout (1 s since Rails 8.0 defaults) while precompiling.
# It guards puma threads against ReDoS; precompiling parses only our own
# assets. Terser's sourceMappingURL scan of the 4.7 MB esbuild bundle
# takes ~40 ms natively but over 1 s under QEMU (arm64 Docker image).
Rake::Task['assets:environment'].enhance { Regexp.timeout = nil }
