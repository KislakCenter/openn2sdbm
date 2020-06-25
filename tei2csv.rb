#!/usr/bin/env ruby

# require 'nokogiri'
require 'csv'
require 'open-uri'
# pull in the file that parses the data
require_relative './lib/tei_data'

source_csv = ARGV.shift
abort "Please provide on openn source CSV file" unless source_csv
abort "Can't find CSV file: '#{source_csv}''"   unless File.exist? source_csv

BASE_URI = 'http://openn.library.upenn.edu/Data'

headers = %i{
  collection id manuscript groups source_date source_title
  source_catalog_or_lot_number sale_selling_agent sale_seller_or_holder
  sale_buyer sale_sold sale_price titles authors dates date_ranges artists
  scribes languages materials places uses folios num_columns num_lines height
  width alt_size miniatures_fullpage miniatures_large miniatures_small
  miniatures_unspec_size initials_historiated initials_decorated
  manuscript_binding manuscript_link other_info provenance created_at
  created_by updated_at updated_by approved deprecated superceded_by_id draft
  extent layout
}

CSV headers: true do |csv|
  csv << headers
  # curated_collection,document_id,path,repository_id,metadata_type,title,added,document_created,document_updated
  # muslimworld,6847,0032/ms_or_015,0032,TEI,Sharh-i sad kalimah-i Batlamiyus.,2018-12-19T15:33:38+00:00,2018-12-18T21:36:56+00:00,2019-01-25T21:41:18+00:00
  # muslimworld,6849,0032/ms_or_019,0032,TEI,Panjah bab-i sultani bi-`ilm-i usturlab.,2018-12-19T19:00:13+00:00,2018-12-19T17:42:27+00:00,2019-01-28T14:43:05+00:00
  # muslimworld,6850,0032/ms_or_024,0032,TEI,Calendar for year 1064 AH,2018-12-19T19:00:26+00:00,2018-12-19T18:07:53+00:00,2019-01-28T14:43:12+00:00
  # muslimworld,6851,0032/ms_or_025,0032,TEI,Kitab al-ukar.,2018-12-19T19:00:40+00:00,2018-12-19T18:10:47+00:00,2019-01-28T14:43:19+00:00
  CSV.parse URI.open(source_csv).read, headers: true do |row|
    path = row['path']
    base = File.basename path
    tei_file = "#{BASE_URI}/#{path}/data/#{base}_TEI.xml"
    out_row = extract_data URI.open tei_file
    # we need to add collection and url
    out_row[:collection] = collection_name row['repository_id']
    out_row[:manuscript_link] = tei_file

    csv << out_row
  end
end

