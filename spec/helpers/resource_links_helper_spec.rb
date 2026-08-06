# frozen_string_literal: true

require 'rails_helper'

describe ResourceLinksHelper do
  include ResourceLinksHelper

  let(:concept)  { 'http://opendata.inrae.fr/thesaurusINRAE/c_01cd9294' }
  let(:note)     { 'http://opendata.inrae.fr/thesaurusINRAE/note_101800en' }
  let(:ontology) { 'http://opendata.inrae.fr/thesaurusINRAE/thesaurusINRAE' }

  describe '#uri_namespace' do
    it 'keeps everything up to the last slash' do
      expect(uri_namespace(note)).to eq('http://opendata.inrae.fr/thesaurusINRAE/')
    end

    it 'keeps everything up to the last hash' do
      expect(uri_namespace('http://www.w3.org/2002/07/owl#Thing')).to eq('http://www.w3.org/2002/07/owl#')
    end

    it 'is nil for a value that is not a URI' do
      expect(uri_namespace('crop establishment')).to be_nil
    end
  end

  describe '#same_namespace?' do
    it 'holds for two URIs minted by the same ontology' do
      expect(same_namespace?(note, concept)).to be true
      expect(same_namespace?(note, ontology)).to be true
    end

    it 'rejects a URI borrowed from another vocabulary' do
      expect(same_namespace?('http://www.w3.org/2002/07/owl#Thing', concept)).to be false
      expect(same_namespace?('http://purl.org/dc/terms/source', concept)).to be false
    end

    it 'rejects a value that is not an http(s) URI' do
      expect(same_namespace?('crop establishment', concept)).to be false
      expect(same_namespace?(nil, concept)).to be false
      expect(same_namespace?('urn:uuid:1234', concept)).to be false
    end

    it 'lets the API decide when there is nothing to compare against' do
      expect(same_namespace?(note, nil)).to be true
      expect(same_namespace?(note, '')).to be true
    end
  end

  describe '#reified_resource_chip' do
    it 'never looks up a URI from another vocabulary' do
      expect(ResourceLookupService).not_to receive(:call)

      expect(reified_resource_chip('TEST', 'http://www.w3.org/2002/07/owl#Thing', parent_uri: concept)).to be_nil
    end

    it 'falls back to the caller when no source knows the resource' do
      allow(ResourceLookupService).to receive(:call).and_return(nil)

      expect(reified_resource_chip('TEST', note, parent_uri: concept)).to be_nil
    end
  end

  describe '#resource_modal_path' do
    it 'points at the instances page, which serves any resource of the submission' do
      expect(resource_modal_path('TEST', note))
        .to eq('/ontologies/TEST/instances/show?instanceid=http%3A%2F%2Fopendata.inrae.fr%2FthesaurusINRAE%2Fnote_101800en&modal=true')
    end
  end

  # Provided by UrlsHelper in the app.
  def escape(string)
    CGI.escape(string) if string
  end
end
