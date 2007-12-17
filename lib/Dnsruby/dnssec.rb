# @TODO@
# RFC4033, section 7
#   There is one more step that a security-aware stub resolver can take
#   if, for whatever reason, it is not able to establish a useful trust
#   relationship with the recursive name servers that it uses: it can
#   perform its own signature validation by setting the Checking Disabled
#   (CD) bit in its query messages.  A validating stub resolver is thus
#   able to treat the DNSSEC signatures as trust relationships between
#   the zone administrators and the stub resolver itself. 

module Dnsruby
  class DnssecVerifier
    # @TODO@ Maybe write a recursive validating resolver?
    def initialize
    
    end
  
    def self.check_rr_data(rrset, sigrec)
      #Each RR MUST have the same owner name as the RRSIG RR;
      if (rrset.name.to_s != sigrec.name.to_s)
        raise VerifyError.new("RRSET should have same owner name as RRSIG for verification (rrsert=#{rrset.name}, sigrec=#{sigrec.name}")
      end

      #Each RR MUST have the same class as the RRSIG RR;
      if (rrset.klass != sigrec.klass)
        raise VerifyError.new("RRSET should have same DNS class as RRSIG for verification")
      end

      #Each RR in the RRset MUST have the RR type listed in the
      #RRSIG RR's Type Covered field;
      if (rrset.type != sigrec.type_covered)
        raise VerifyError.new("RRSET should have same type as RRSIG for verification")
      end

      #Each RR in the RRset MUST have the TTL listed in the
      #RRSIG Original TTL Field;
      if (rrset.ttl  != sigrec.ttl)
        raise VerifyError.new("RRSET should have same ttl as RRSIG for verification")
      end
    
      # Now check that we are in the validity period for the RRSIG
      now = Time.now.to_i
      if ((sigrec.expiration < now) || (sigrec.inception > now))
        raise VerifyError.new("Signature record not in validity period")
      end
    end
  
    # Verify the signature of an rrset encoded with the specified dnskey record
    def self.verify_signature(rrset, sigrec, keyrec)
      # RFC 4034
      #3.1.8.1.  Signature Calculation
      
      if (keyrec.sep_key? && !keyrec.zone_key?)
        TheLog.error("DNSKEY with with SEP flag set and Zone Key flag not set was used to verify RRSIG over RRSET - this is not allowed by RFC4034 section 2.1.1")
        # @TODO@ Raise an exception?
        return false
      end
    
      check_rr_data(rrset, sigrec)

      #Any DNS names in the RDATA field of each RR MUST be in
      #canonical form; and
      #The RRset MUST be sorted in canonical order.
      rrset = rrset.sort_canonical

      sig_data =sigrec.sig_data

      #RR(i) = owner | type | class | TTL | RDATA length | RDATA
      rrset.each do |rec|
        data = MessageEncoder.new { |msg|
          msg.put_rr(rec, true)
        }.to_s # @TODO@ worry about wildcards here?
        sig_data += data
      end
      
      # Now calculate the signature
      verified = false
      if (sigrec.algorithm == Algorithms.RSASHA1)
        verified = keyrec.public_key.verify(OpenSSL::Digest::SHA1.new, sigrec.signature, sig_data)
      elsif (sigrec.algorithm == HMAC_SHA256)
        verified = keyrec.public_key.verify(OpenSSL::Digest::SHA256.new, sigrec.signature, sig_data)
      else
        raise RuntimeError.new("Algorithm #{sigrec.algorithm.string} unsupported by Dnsruby")
      end
    
      # And compare the signature with the rrsig signature field
      return verified
      
      # @TODO@
      #If the resolver accepts the RRset as authentic, the validator MUST
      #set the TTL of the RRSIG RR and each RR in the authenticated RRset to
      #a value no greater than the minimum of:

      #o  the RRset's TTL as received in the response;

      #o  the RRSIG RR's TTL as received in the response;

      #o  the value in the RRSIG RR's Original TTL field; and

      #o  the difference of the RRSIG RR's Signature Expiration time and the
      #current time.
    end
  
    # @TODO@ Add methods which look up a cache of trusted keys to sign rrset
    
    # @TODO@ Add methods which search for correct key_tag in DNSKEYs for RRSIG
    
  end
end