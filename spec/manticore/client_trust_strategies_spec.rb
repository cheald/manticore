# encoding: utf-8
require "spec_helper"
describe Manticore::Client::TrustStrategies do
  describe '#coerce' do
    subject(:coerced) { described_class.coerce(input) }
    context 'with a nil value' do
      let(:input) { nil }
      it 'returns the value unchanged' do
        expect(coerced).to be_nil
      end
    end
    context 'with an implementation of org.apache.http.conn.ssl.TrustStrategy' do
      let(:input) { org.apache.http.conn.ssl.TrustAllStrategy::INSTANCE }
      it 'returns the value unchanged' do
        expect(coerced).to be input
      end
    end
    context 'with a Proc' do
      let(:input) { ->(chain, type) { true } }
      it 'wraps the proc in a `CustomTrustStrategy`' do
        expect(Manticore::Client::CustomTrustStrategy).to receive(:new).with(input).and_call_original
        expect(described_class.coerce(input)).to be_a_kind_of Manticore::Client::CustomTrustStrategy
      end
    end
  end

  describe '#combine' do
    context 'when left-hand value is nil' do
      let(:left_hand_strategy) { nil }
      let(:right_hand_strategy) { described_class.coerce(->(chain,type){ true }) }
      it 'returns the right-hand value coerced' do
        expect(described_class).to receive(:coerce).with(right_hand_strategy).and_call_original
        expect(described_class.combine(left_hand_strategy, right_hand_strategy)).to be right_hand_strategy
      end
    end
    context 'when the right-hand value is nil' do
      let(:left_hand_strategy) {  described_class.coerce(->(chain,type){ true }) }
      let(:right_hand_strategy) { nil }
      it 'returns the left-hand value coerced' do
        expect(described_class).to receive(:coerce).with(left_hand_strategy).and_call_original
        expect(described_class.combine(left_hand_strategy, right_hand_strategy)).to be left_hand_strategy
      end
    end
    context 'when neither value is nil' do
      let(:left_hand_strategy) {  described_class.coerce(->(chain,type){ true }) }
      let(:right_hand_strategy) { described_class.coerce(->(chain,type){ true }) }

      it 'returns a CombinedTrustStrategy' do
        expect(Manticore::Client::CombinedTrustStrategy)
          .to receive(:new).with(left_hand_strategy, right_hand_strategy).and_call_original

        # ensures that the values are coerced.
        expect(described_class).to receive(:coerce).with(left_hand_strategy).and_call_original
        expect(described_class).to receive(:coerce).with(right_hand_strategy).and_call_original

        combined = described_class.combine(left_hand_strategy, right_hand_strategy)
        expect(combined).to be_a_kind_of Manticore::Client::CombinedTrustStrategy
      end
    end
    context 'when both values are nil' do
      let(:left_hand_strategy) { nil }
      let(:right_hand_strategy) { nil }

      it 'returns nil' do
        expect(described_class.combine(left_hand_strategy, right_hand_strategy)).to be nil
      end
    end
  end
end

describe Manticore::Client::CustomTrustStrategy do

  subject(:custom_trust_strategy) { described_class.new(trust_strategy_proc) }

  context 'when called via Java interface' do
    def load_java_cert(file_path)
      pem_contents = File.read(file_path)
      cf = java.security.cert.CertificateFactory::getInstance("X.509")
      is = java.io.ByteArrayInputStream.new(pem_contents.to_java_bytes)
      cf.generateCertificate(is)
    end

    let(:java_host_cert) { load_java_cert(File.expand_path("../../ssl/host.crt", __FILE__)) }
    let(:java_root_cert) { load_java_cert(File.expand_path("../../ssl/root-ca.crt", __FILE__)) }
    let(:java_chain) { [java_host_cert, java_root_cert].to_java(java.security.cert.X509Certificate) }
    let(:java_type) { java.lang.String.new("my_type".to_java_bytes) }

    subject(:java_trust_strategy) { custom_trust_strategy.to_java(org.apache.http.conn.ssl.TrustStrategy) }

    context 'when called with Java Certs and a Java String' do
      let(:trust_strategy_proc) { ->(chain,type) { true } }
      it 'yields an enum of equivalent Ruby certs and an equivalent Ruby String' do
        expect(trust_strategy_proc).to receive(:call) do |chain, type|
          expect(chain.to_a.length).to eq java_chain.length
          chain.each_with_index do |cert, idx|
            expect(cert).to be_a_kind_of OpenSSL::X509::Certificate
            expect(cert.to_der).to eq String.from_java_bytes(java_chain[idx].encoded)
          end
          expect(type).to be_a_kind_of String
          expect(type).to eq String.from_java_bytes(java_type.bytes)
        end

        expect(java_trust_strategy.isTrusted(java_chain, java_type)).to be true
      end
    end

    context 'when the ruby block returns false' do
      let(:trust_strategy_proc) { ->(chain,type) { false } }
      it 'returns false' do
        expect(java_trust_strategy.isTrusted(java_chain, java_type)).to be false
      end
    end

    context 'when the ruby block returns true' do
      let(:trust_strategy_proc) { ->(chain,type) { true } }
      it 'returns true' do
        expect(java_trust_strategy.isTrusted(java_chain, java_type)).to be true
      end
    end

    context 'when the ruby block raises an exception' do
      let(:trust_strategy_proc) { ->(chain, type) { fail(OpenSSL::X509::CertificateError, 'intentional') } }
      it 'throws a CertificateException' do
        expect {
          java_trust_strategy.isTrusted(java_chain, java_type)
        }.to raise_exception(java.security.cert.CertificateException)
      end
    end
  end
end

describe Manticore::Client::CombinedTrustStrategy do
  let(:always_trust_strategy) { ->(chain,type) { true } }
  let(:never_trust_strategy) { ->(chain,type) { false } }

  subject(:combined_trust_strategy) { Manticore::Client::TrustStrategies.combine(left_hand_strategy, right_hand_strategy) }

  context 'when left-hand strategy trusts' do
    let(:left_hand_strategy) { always_trust_strategy }
    context 'when right-hand strategy trusts' do
      let(:right_hand_strategy) { always_trust_strategy }
      it 'trusts' do
        expect(combined_trust_strategy.trusted?([],'ignored')).to be true
      end
    end
    context 'when right-hand strategy does not trust' do
      let(:right_hand_strategy) { never_trust_strategy }
      it 'trusts' do
        expect(combined_trust_strategy.trusted?([],'ignored')).to be true
      end
    end
  end
  context 'when left-hand strategy does not trust' do
    let(:left_hand_strategy) { never_trust_strategy }
    context 'when right-hand strategy trusts' do
      let(:right_hand_strategy) { always_trust_strategy }
      it 'trusts' do
        expect(combined_trust_strategy.trusted?([],'ignored')).to be true
      end
    end
    context 'when right-hand strategy does not trust' do
      let(:right_hand_strategy) { never_trust_strategy }
      it 'does not trust' do
        expect(combined_trust_strategy.trusted?([],'ignored')).to be false
      end
    end
  end
end
