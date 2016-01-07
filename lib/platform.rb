class Platform
  # rubocop: disable Metrics/LineLength, Metrics/CyclomaticComplexity
  def self.family(platform)
    case platform.to_s.downcase
    when /debian/, /ubuntu/, /linuxmint/, /raspbian/
      'debian'
    when /fedora/, /pidora/
      'fedora'
    when /oracle/, /centos/, /redhat/, /scientific/, /enterpriseenterprise/, /amazon/, /xenserver/, /cloudlinux/, /ibm _powerkvm/, /parallels/, /nexus_centos/
      'rhel'
    when /suse/
      'suse'
    when /gentoo/
      'gentoo'
    when /slackware/
      'slackware'
    when /arch/
      'arch'
    when /exherbo/
      'exherbo'
    when /windows/
      'windows'
    end
  end
end
