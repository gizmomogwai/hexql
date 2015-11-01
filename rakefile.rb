task :build do
	sh "xcodebuild build"
end

filename = "HexQL.qlgenerator-#{Time.now.to_s.split()[0]}.tar.bz2"
task :compress => :build do
	sh "tar cjvf #{filename} -C ~/Library/QuickLook HexQL.qlgenerator"
end

task :default => :install
