require 'spec_helper'

describe Gmail::Labels do
  context '#localize' do
    context 'when given the XLIST flag ' do
      [:Inbox, :All, :Drafts, :Sent, :Trash, :Important, :Junk, :Flagged].each do |flag|
        context flag do
          it 'localizes into the appropriate label' do
            localized = ""
            mock_client { |client| localized = client.labels.localize(flag) }
            localized.should be_a_kind_of(String)
            localized.should match(/\[Gmail|Google Mail\]|Inbox/i)
          end
        end
      end

      context 'which does not exist on server' do
        it 'raises a UnknownMailbox exception' do
          expect do
            mock_connection = mock()
            mock_connection.expects(:list).returns([])
            labels = Gmail::Labels.new mock_connection
            labels.localize(:all)
          end.to raise_error(Gmail::Client::UnknownMailbox)
        end
      end
    end
  end
end