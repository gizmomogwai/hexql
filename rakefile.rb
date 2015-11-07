desc 'build and test'
task :build do
  sh "xctool -workspace HexQL.xcodeproj/project.xcworkspace -scheme HexQL build test"
end

filename = "HexQL.qlgenerator-#{Time.now.to_s.split()[0]}.tar.bz2"
desc 'compress release'
task :compress => :build do
  sh "tar cjvf #{filename} -C ~/Library/QuickLook HexQL.qlgenerator"
end

desc 'install'
task :install => :build do
  sh "qlmanage -r"
end

task :default => :install
