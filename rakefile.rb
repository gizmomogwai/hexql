task :build do
  sh "xcodebuild -project HexQL.xcodeproj -scheme HexQLApp -configuration Release SYMROOT=build build"
end

task :install do
  sh "cp -r build/Release/HexQL.app ~/Applications/"
end


task :default => [:build, :install]