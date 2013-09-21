#
#    Copyright (C) 2012 eNovance <licensing@enovance.com>
#	
#    Author: Loic Dachary <loic@dachary.org>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
Puppet::Parser::Functions::newfunction(:tinc_keygen, :type => :rvalue, :doc =>
  "Returns an array containing the tinc private and public (in this order) key.") do |args|
  raise Puppet::ParseError, "There must be exactly one argument, the directory in which keys are created" if args.to_a.length != 1
  dir = args.to_a[0]
  ::FileUtils.mkdir_p(dir)
  private_key_path = File.join(dir, "rsa_key.priv")
  public_key_path = File.join(dir, "rsa_key.pub")
  if ! File.exists?(private_key_path) || ! File.exists?(public_key_path)
    output = Puppet::Util.execute(['/usr/sbin/tincd', '--config', dir, '--generate-keys'])
    raise Puppet::ParseError, "/usr/sbin/tincd --config #{dir} --generate-keys output does not match the 'Generating .* bits keys' regular expression. #{output}" unless output =~ /Generating .* bits keys/
  end
  [ File.read(private_key_path), File.read(public_key_path) ]
end
