require 'spec_helper'

describe Fasterer::FileTraverser do
  include FileHelper
  include_context 'isolated environment'

  describe 'config_file' do
    context 'with no config file' do
      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns nil_config_file' do
        expect(file_traverser.config_file)
          .to eq(file_traverser.send(:nil_config_file))
      end
    end

    context 'with empty config file' do
      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME, '')
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns nil_config_file' do
        expect(file_traverser.config_file)
          .to eq(file_traverser.send(:nil_config_file))
      end
    end

    context 'missing exclude_paths key' do
      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME,
                    ['speedups:'])
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns nil_config_file' do
        expect(file_traverser.config_file)
          .to eq(file_traverser.send(:nil_config_file))
      end
    end

    context 'with speedups content but no exclude_paths' do
      let(:config_file_content) do
        "speedups:\n"\
        "  keys_each_vs_each_key: true"
      end

      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME,
                    config_file_content)
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns config_file with added exclude paths key' do
        expect(file_traverser.config_file)
          .to eq('speedups' => { 'keys_each_vs_each_key' => true },
                 'exclude_paths' => [])
      end
    end

    context 'with exclude_paths content but no speedups' do
      let(:config_file_content) do
        "exclude_paths:\n"\
        "  - 'spec/support/analyzer/*.rb'"
      end

      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME,
                    config_file_content)
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns config_file with added speedups key' do
        expect(file_traverser.config_file)
          .to eq('speedups' => {},
                 'exclude_paths' => ['spec/support/analyzer/*.rb'])
      end
    end

    context 'with exclude_paths and speedups content' do
      let(:config_file_content) do
        "speedups:\n"\
        "  keys_each_vs_each_key: true\n"\
        "exclude_paths:\n"\
        "  - 'spec/support/analyzer/*.rb'"
      end

      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME,
                    config_file_content)
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns config_file' do
        expect(file_traverser.config_file)
          .to eq('speedups' => { 'keys_each_vs_each_key' => true },
                 'exclude_paths' => ['spec/support/analyzer/*.rb'])
      end
    end

    context 'with empty values' do
      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME,
                    ['speedups:',
                     '',
                     'exclude_paths:'])
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns nil_config_file' do
        expect(file_traverser.config_file)
          .to eq(file_traverser.send(:nil_config_file))
      end
    end
  end

  describe 'scannable files' do
    context 'when no files in folder' do
      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns empty array' do
        expect(file_traverser.send(:scannable_files)).to eq([])
      end
    end

    context 'only a non-ruby file inside' do
      before do
        create_file('something.yml')
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns empty array' do
        expect(file_traverser.send(:scannable_files)).to eq([])
      end
    end

    context 'a ruby file inside' do
      let(:file_name) { 'something.rb' }

      before do
        create_file(file_name)
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns array with that file inside' do
        expect(file_traverser.send(:scannable_files)).to eq([file_name])
      end
    end

    context 'a ruby file inside that is ignored' do
      let(:file_name) { 'something.rb' }

      let(:config_file_content) do
        "exclude_paths:\n"\
        "  - '#{file_name}'"
      end

      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME,
                    config_file_content)

        create_file(file_name)
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns empty array' do
        expect(file_traverser.send(:scannable_files)).to eq([])
      end
    end

    context 'a ruby file inside that is not ignored' do
      let(:file_name) { 'something.rb' }

      let(:config_file_content) do
        "exclude_paths:\n"\
        "  - 'sumthing.rb'"
      end

      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
        create_file(file_name)
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns empty array' do
        expect(file_traverser.send(:scannable_files)).to eq([file_name])
      end
    end

    context 'nested ruby files' do
      before(:each) do
        create_file('something.rb')
        create_file('nested/something.rb')
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns files properly' do
        expect(file_traverser.send(:scannable_files))
          .to match_array(['something.rb', 'nested/something.rb'])
      end
    end

    context 'ruby files but nested ignored explicitly' do
      let(:config_file_content) do
        "exclude_paths:\n"\
        "  - 'nested/something.rb'"
      end

      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
        create_file('something.rb')
        create_file('nested/something.rb')
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns unignored files' do
        expect(file_traverser.send(:scannable_files))
          .to match_array(['something.rb'])
      end
    end

    context 'ruby files but nested ignored with *' do
      let(:config_file_content) do
        "exclude_paths:\n"\
        "  - 'nested/*'"
      end

      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
        create_file('something.rb')
        create_file('nested/something.rb')
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns unignored files' do
        expect(file_traverser.send(:scannable_files))
          .to match_array(['something.rb'])
      end
    end

    context 'ruby files but unnested ignored' do
      let(:config_file_content) do
        "exclude_paths:\n"\
        "  - 'something.rb'"
      end

      before(:each) do
        create_file(Fasterer::FileTraverser::CONFIG_FILE_NAME, config_file_content)
        create_file('something.rb')
        create_file('nested/something.rb')
      end

      let(:file_traverser) { Fasterer::FileTraverser.new('.') }

      it 'returns unignored files' do
        expect(file_traverser.send(:scannable_files))
          .to match_array(['nested/something.rb'])
      end
    end
  end

  describe 'parse errors' do
    before do
      create_file('user.rb', '[]*/sa*()')
      file_traverser.traverse
    end

    let(:file_traverser) { Fasterer::FileTraverser.new('.') }

    it 'should have errors' do
      expect(file_traverser.parse_error_paths)
        .to match_array(['user.rb - RubyParser::SyntaxError - unterminated string meets end of file. near line 1: ""'])
    end
  end
end