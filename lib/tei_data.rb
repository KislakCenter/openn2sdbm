#!/usr/bin/env ruby

require 'nokogiri'
require 'iso-639'
require 'csv'
require 'open-uri'

COLLECTION_CSV_URI = 'https://openn.library.upenn.edu/Data/collections.csv'.freeze

def collection_data
  return @collection_data if @collection_data
  @collection_data = {}
  # repository_id,collection_tag,collection_type,metadata_type,collection_name
  URI.open(COLLECTION_CSV_URI) { |f| CSV.parse f, headers: true }.each do |row|
    repository_id = sprintf '%04d', row['repository_id'].to_i
    @collection_data[repository_id] = row['collection_name']
  end
  @collection_data
end

def collection_name collection_id
  # binding.pry
  collection_data[sprintf '%04d', collection_id.to_i]
end

def extract_langs xml
  langs = []
  langs << xml.xpath('//msDesc/msContents/textLang/@mainLang').first.text
  unless xml.xpath('//msDesc/msContents/textLang/@otherLangs').empty?
    langs += xml.xpath('//msDesc/msContents/textLang/@otherLangs').first.text.split
  end
  # binding.pry
  langs.map { |x| ISO_639.find_by_code(x).english_name }.join ';'
end

# TODO: Email repository list to Emma
# TODO: Look at 500 fields and figure out what does into "other_info"
# TODO: Pull in decorations, script, notes, origin into "other_info" as a block http://openn.library.upenn.edu/Data/0032/html/ms_or_045.html
# TODO: Pull in Vernacular script with titles and names (authors, etc.)


def extract_provenance xml
  # TODO: Move origin to other info
  (prov ||= []) << xml.xpath('/TEI/teiHeader/fileDesc/sourceDesc/msDesc/history/origin/p').text
  unless xml.xpath('/TEI/teiHeader/fileDesc/sourceDesc/msDesc/history/provenance').empty?
    prov += xml.xpath('/TEI/teiHeader/fileDesc/sourceDesc/msDesc/history/provenance').map(&:text).uniq
  end
  prov.join ';'
end

def extract_first xml, xpath
  return if xml.xpath(xpath).empty?
  xml.xpath(xpath).first.text
end

def extract_data file
  doc = Nokogiri::XML file
  doc.remove_namespaces!
  # collection
  # id
  # manuscript
  # groups
  # source_date
  # source_title
  # source_catalog_or_lot_number
  source_catalog_or_lot_number = doc.xpath('/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msIdentifier/idno[@type="call-number"]').text
  # sale_selling_agent
  # sale_seller_or_holder
  # sale_buyer
  # sale_sold
  # sale_price
  # titles
  titles = doc.xpath('//msItem/title[not(@type="vernacular")]').map(&:text).uniq.join ';'
  # authors =
  authors = doc.xpath('//msContents/msItem/author/persName[not(@type="vernacular")]').map(&:text).uniq.join ';'
  # dates
  dates = doc.xpath('/TEI/teiHeader/fileDesc/sourceDesc/msDesc/history/origin/origDate').map(&:text).uniq.join ';'
  # date_ranges
  # artists
  artists = doc.xpath('//msContents/msItem/respStmt/resp[text()="artist"]/../persName[not(@type="vernacular")]').map(&:text).uniq.join ';'
  # scribes
  scribes = doc.xpath('//msContents/msItem/respStmt/resp[text()="scribe"]/../persName[not(@type="vernacular")]').map(&:text).uniq.join ';'
  # languages
  languages = extract_langs doc
  # materials
  materials = extract_first doc, '/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/support/p'
  # places
  places = doc.xpath('/TEI/teiHeader/fileDesc/sourceDesc/msDesc/history/origin/origPlace').map(&:text).uniq.join ';'
  # uses
  # folios
  # num_columns
  # num_lines
  # height
  # width
  # alt_size
  # miniatures_fullpage
  # miniatures_large
  # miniatures_small
  # miniatures_unspec_size
  # initials_historiated
  # initials_decorated
  # manuscript_binding
  manuscript_binding = doc.xpath('/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/bindingDesc/binding/p').map(&:text).uniq.join ';'
  # manuscript_link
  # other_info
  # provenance
  provenance = extract_provenance doc
  # created_at
  # created_by
  # updated_at
  # updated_by
  # approved
  # deprecated
  # superceded_by_id
  # draft
  # extent
  extent = extract_first doc, '/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/extent'
  # layout
  layout = extract_first doc, '/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/layoutDesc/layout'

  {
      source_catalog_or_lot_number: source_catalog_or_lot_number,
      titles:                       titles,
      authors:                      authors,
      dates:                        dates,
      artists:                      artists,
      scribes:                      scribes,
      languages:                    languages,
      materials:                    materials,
      places:                       places,
      manuscript_binding:           manuscript_binding,
      provenance:                   provenance,
      extent:                       extent,
      layout:                       layout,
  }
end
#
# tei_file = ARGV.shift
#
# data = extract_data open tei_file
#
# puts data

# puts collection_name 10