# -*- encoding: utf-8 -*-
# stub: rake-compiler-dock 1.11.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rake-compiler-dock".freeze
  s.version = "1.11.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Lars Kanis".freeze]
  s.cert_chain = ["-----BEGIN CERTIFICATE-----\nMIIEBDCCAmygAwIBAgIBAzANBgkqhkiG9w0BAQsFADAoMSYwJAYDVQQDDB1sYXJz\nL0RDPWdyZWl6LXJlaW5zZG9yZi9EQz1kZTAeFw0yNDEyMjkxOTU2NTZaFw0yNTEy\nMjkxOTU2NTZaMCgxJjAkBgNVBAMMHWxhcnMvREM9Z3JlaXotcmVpbnNkb3JmL0RD\nPWRlMIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAwum6Y1KznfpzXOT/\nmZgJTBbxZuuZF49Fq3K0WA67YBzNlDv95qzSp7V/7Ek3NCcnT7G+2kSuhNo1FhdN\neSDO/moYebZNAcu3iqLsuzuULXPLuoU0GsMnVMqV9DZPh7cQHE5EBZ7hlzDBK7k/\n8nBMvR0mHo77kIkapHc26UzVq/G0nKLfDsIHXVylto3PjzOumjG6GhmFN4r3cP6e\nSDfl1FSeRYVpt4kmQULz/zdSaOH3AjAq7PM2Z91iGwQvoUXMANH2v89OWjQO/NHe\nJMNDFsmHK/6Ji4Kk48Z3TyscHQnipAID5GhS1oD21/WePdj7GhmbF5gBzkV5uepd\neJQPgWGwrQW/Z2oPjRuJrRofzWfrMWqbOahj9uth6WSxhNexUtbjk6P8emmXOJi5\nchQPnWX+N3Gj+jjYxqTFdwT7Mj3pv1VHa+aNUbqSPpvJeDyxRIuo9hvzDaBHb/Cg\n9qRVcm8a96n4t7y2lrX1oookY6bkBaxWOMtWlqIprq8JZXM9AgMBAAGjOTA3MAkG\nA1UdEwQCMAAwCwYDVR0PBAQDAgSwMB0GA1UdDgQWBBQ4h1tIyvdUWtMI739xMzTR\n7EfMFzANBgkqhkiG9w0BAQsFAAOCAYEAoZZWzNV2XXaoSmvyamSSN+Wt/Ia+DNrU\n2pc3kMEqykH6l1WiVPszr6HavQ//2I2UcSRSS5AGDdiSXcfyFmHtMBdtJHhTPcn7\n4DLliB0szpvwG+ltGD8PI8eWkLaTQeFzs+0QCTavgKV+Zw56Q0J5zZvHHUMrLkUD\nqhwKjdTdkrRTn9Sqi0BrIRRZGTUDdrt8qoWm35aES5arKZzytgrRD/kXfFW2LCg0\nFzgTKibR4/3g8ph94kQLg/D2SMlVPkQ3ECi036mZxDC2n8V6u3rDkG5923wmrRZB\nJ6cqz475Q8HYORQCB68OPzkWMfC7mBo3vpSsIqRoNs1FE4FJu4FGwZG8fBSrDC4H\nbZe+GtyS3e2SMjgT65zp35gLO9I7MquzYN9P6V2u1iBpTycchk5z9R1ghxzZSBT8\nDrkJ9tVlPQtJB0LqT0tvBap4upnwT1xYq721b5dwH6AF4Pi6iz/dc5vnq1/MH8bV\n8VbbBzzeE7MsvgkP3sHlLmY8PtuyViJ8\n-----END CERTIFICATE-----\n".freeze]
  s.date = "1980-01-02"
  s.description = "Easy to use and reliable cross compiler environment for building Windows and Linux binary gems.\nUse rake-compiler-dock to enter an interactive shell session or add a task to your Rakefile to automate your cross build.".freeze
  s.email = ["lars@greiz-reinsdorf.de".freeze]
  s.executables = ["rake-compiler-dock".freeze]
  s.files = ["bin/rake-compiler-dock".freeze]
  s.homepage = "https://github.com/rake-compiler/rake-compiler-dock".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "4.0.3".freeze
  s.summary = "Easy to use and reliable cross compiler environment for building Windows and Linux binary gems.".freeze

  s.installed_by_version = "3.5.22".freeze

  s.specification_version = 4

  s.add_development_dependency(%q<bundler>.freeze, [">= 1.7".freeze, "< 3.0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 12".freeze])
  s.add_development_dependency(%q<test-unit>.freeze, ["~> 3.0".freeze])
end
