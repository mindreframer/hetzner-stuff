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
require 'mocha'
require 'fileutils'

describe "tinc_keygen function" do

  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should exist" do
    Puppet::Parser::Functions.function("tinc_keygen").should == "function_tinc_keygen"
  end

  it "should complain if there are no arguments" do
    lambda { @scope.function_tinc_keygen() }.should( raise_error(Puppet::ParseError, /exactly one argument/))
  end

  describe "when executing properly" do
    before do
      @private_path = '/tmp/rsa_key.priv'
      @public_path = '/tmp/rsa_key.pub'
      @private_key = 'private key'
      @public_key = 'public key'
      FileUtils.expects(:mkdir_p).with('/tmp')
      File.stubs(:exists?).with(@private_path).returns(true)
      File.stubs(:exists?).with(@public_path).returns(false)
    end

    it "should generate the private and public keys" do
      File.stubs(:read).with(@private_path).returns(@private_key)
      File.stubs(:read).with(@public_path).returns(@public_key)
      Puppet::Util.expects(:execute).with(['/usr/sbin/tincd', '--config', '/tmp', '--generate-keys']).returns("XXXXX\nGenerating 2048 bits keys\nXXXXXXXX")
      result = @scope.function_tinc_keygen('/tmp')
      result.length.should == 2
      result[0].should == @private_key
      result[1].should == @public_key
    end

    it "should fail if the output does not contain the expected pattern" do
      unexpected_output = 'ZZZZZZZZZZZZZ'
      Puppet::Util.expects(:execute).with(['/usr/sbin/tincd', '--config', '/tmp', '--generate-keys']).returns(unexpected_output)
      lambda { @scope.function_tinc_keygen('/tmp') }.should( raise_error(Puppet::ParseError, /ZZZZZZZZZZZZ/))
    end
  end
end
