#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'dart_duckdb'
  s.version          = File.read(File.join('..', 'pubspec.yaml')).match(/version:\s+(\d+\.\d+\.\d+)/)[1]
  s.summary          = 'DuckDB embedded database for Flutter iOS.'
  s.description      = <<-DESC
DuckDB for Flutter iOS. Uses an XCFramework with device + simulator slices.
                        DESC
  s.homepage         = 'https://github.com/TigerEyeLabs/duckdb-dart'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tigereye' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'

  s.platform = :ios, '11.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  # Device-only .framework fails simulator linking; XCFramework has both.
  s.ios.vendored_frameworks = 'Libraries/release/duckdb.xcframework'

  # Upstream TigerEyeLabs zips are device-only / missing tags. Use the
  # community XCFramework release that includes ios-arm64-simulator.
  s.prepare_command = <<-CMD
    set -e
    mkdir -p Libraries/release
    if [ ! -d "Libraries/release/duckdb.xcframework" ]; then
      echo "Downloading DuckDB iOS XCFramework (v1.4.3-ios)..."
      curl -fL -o duckdb-xcframework-ios.zip \\
        "https://github.com/yharby/duckdb-dart/releases/download/v1.4.3-ios/duckdb-xcframework-ios.zip"
      unzip -o duckdb-xcframework-ios.zip -d Libraries/release/
      rm duckdb-xcframework-ios.zip
      # Zip may nest the xcframework one level deeper.
      if [ ! -d "Libraries/release/duckdb.xcframework" ]; then
        found=$(find Libraries/release -type d -name 'duckdb.xcframework' | head -1)
        if [ -n "$found" ] && [ "$found" != "Libraries/release/duckdb.xcframework" ]; then
          mv "$found" Libraries/release/duckdb.xcframework
        fi
      fi
    else
      echo "DuckDB XCFramework already exists."
    fi
    test -d "Libraries/release/duckdb.xcframework"
  CMD
end
