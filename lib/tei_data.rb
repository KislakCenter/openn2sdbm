#!/usr/bin/env ruby

require "nokogiri"
require "iso-639"
require "csv"
require "open-uri"

COLLECTION_CSV_URI = "https://openn.library.upenn.edu/Data/collections.csv".freeze

MULTI_VALUE_SEP = "::::".freeze

def collection_data
  return @collection_data if @collection_data
  @collection_data = {}
  # repository_id,collection_tag,collection_type,metadata_type,collection_name
  URI.open(COLLECTION_CSV_URI) { |f| CSV.parse f, headers: true }.each do |row|
    repository_id = sprintf "%04d", row["repository_id"].to_i
    @collection_data[repository_id] = row["collection_name"]
  end
  @collection_data
end

def collection_name(collection_id)
  # binding.pry
  collection_data[sprintf "%04d", collection_id.to_i]
end

def extract_titles(xml)
  titles = []
  xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msContents/msItem").each do |msItem_node|
    title = msItem_node.xpath('./title[not(@type="vernacular")]').text
    # see if there's vernacular title
    # xpath always returns a nodeset, so we have to see if it's empty or not
    unless msItem_node.xpath('./title[@type="vernacular"]').empty?
      title = "#{title} #{msItem_node.xpath('./title[@type="vernacular"]').text}"
    end
    titles << title
  end
  titles
end

def extract_langs(xml)
  langs = []
  langs << xml.xpath("//msDesc/msContents/textLang/@mainLang").first.text
  unless xml.xpath("//msDesc/msContents/textLang/@otherLangs").empty?
    langs += xml.xpath("//msDesc/msContents/textLang/@otherLangs").first.text.split
  end
  langs.map { |x| ISO_639.find_by_code(x).english_name }.join ";"
end

#authors
def extract_authors(xml)
  authors = []
  xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msContents/msItem/author").each do |author_node|
    next if author_node.xpath('./persName').empty?
    name = author_node.xpath('./persName[not(@type="vernacular")]').text
    # see if there's vernacular persName
    # xpath always returns a nodeset, so we have to see if it's empty or not
    unless author_node.xpath('./persName[@type="vernacular"]').empty?
      name = "#{name} #{author_node.xpath('./persName[@type="vernacular"]').text}"
    end
    authors << name
  end
  authors
end

def extract_artists(xml)
  # <respStmt>
  #   <resp>artist</resp>
  #   <persName type="authority">Saʻdī, Ḥusayn, active 1838</persName>
  #   <persName type="vernacular">سعدي، حسين،</persName>
  # </respStmt>
  artists = []
  xml.xpath('/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msContents/msItem/respStmt[resp/text()="artist"]').each do |artist_node|
    name = artist_node.xpath('./persName[not(@type="vernacular")]').text
    # check for vernacular persName
    # xpath returns nodeset, so we need to check if it's empty
    unless artist_node.xpath('./persName[@type="vernacular"]').empty?
      name = "#{name} #{artist_node.xpath('./persName[@type="vernacular"]').text}"
    end
    artists << name
  end
  artists
end

def extract_scribes(xml)
  # <respStmt>
  #   <resp>scribe</resp>
  #   <persName type="authority">Saʻdī, Ḥusayn, active 1838</persName>
  #   <persName type="vernacular">سعدي، حسين،</persName>
  # </respStmt>
  scribes = []
  xml.xpath('/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msContents/msItem/respStmt[resp/text()="scribe"]').each do |scribe_node|
    name = scribe_node.xpath('./persName[not(@type="vernacular")]').text
    unless scribe_node.xpath('./persName[@type="vernacular"]').empty?
      name = "#{name} #{scribe_node.xpath('./persName[@type="vernacular"]').text}"
    end
    scribes << name
  end
  scribes
end

def empty?(xml, xpath)
  xml.xpath(xpath).empty?
end

def extract_provenance(xml)
  xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/history/provenance").map { |n|
    # provenance is multivalued
    "#{MULTI_VALUE_SEP}#{MULTI_VALUE_SEP}#{n.text}".tr('"', "'")
  }.uniq.join ";"
end

def extract_other_info(xml)
  info = []
  # Summary
  unless xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msContents/summary").empty?
    info << "Summary: #{xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msContents/summary").text}"
  end
  # Notes
  unless empty? xml, "/TEI/teiHeader/fileDesc/notesStmt/note"
    info << xml.xpath("/TEI/teiHeader/fileDesc/notesStmt/note").map(&:text).join("\n")
  end
  # Extent
  unless xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/extent").empty?
    info << "Extent: #{xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/extent").text}"
  end
  # Foliation
  unless xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/foliation").empty?
    info << "Foliation: #{xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/foliation").text}"
  end
  # Collation
  unless xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/collation/p").empty?
    info << "Collation: #{xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/collation/p").text}"
  end
  # Origin
  unless xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/history/origin/p").empty?
    info << "Origin: #{xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/history/origin/p").text}"
  end
  # Colophon
  unless xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msContents/msItem/colophon").empty?
    info << "Colophon: #{xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/msContents/msItem/colophon").text}"
  end
  # Watermark
  unless xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/support/watermark").empty?
    info << "Watermark: #{xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/support/watermark").text}"
  end
  # Layout
  unless xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/layoutDesc/layout").empty?
    info << "Layout: #{xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/layoutDesc/layout").text}"
  end
  # Script
  unless xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/scriptDesc/scriptNote").empty?
    info << "Script: #{xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/scriptDesc/scriptNote").text}"
  end
  # Deconotes
  unless xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/decoDesc/decoNote[not(@n)]").empty?
    info << "Decoration: #{xml.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/decoDesc/decoNote[not(@n)]").text}"
  end
  # Keywords
  unless empty? xml, "/TEI/teiHeader/profileDesc/textClass/keywords/term"
    info << "Keywords: " + xml.xpath("/TEI/teiHeader/profileDesc/textClass/keywords/term").map(&:text).join(";")
  end

  # Join all that stuff with newlines between
  info.join "\n"
end

def extract_first(xml, xpath)
  return if xml.xpath(xpath).empty?
  xml.xpath(xpath).first.text
end

def extract_data(file)
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
  titles = extract_titles(doc).join ";"
  #authors
  authors = extract_authors(doc).join ";"
  # dates
  dates = doc.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/history/origin/origDate").map(&:text).uniq.join ";"
  # date_ranges
  # artists
  artists = extract_artists(doc).join ";"
  # scribes
  scribes = extract_scribes(doc).join ";"
  # languages
  languages = extract_langs doc
  # materials
  materials = extract_first doc, "/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/objectDesc/supportDesc/support/p"
  # places
  places = doc.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/history/origin/origPlace").map(&:text).uniq.join ";"
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
  manuscript_binding = doc.xpath("/TEI/teiHeader/fileDesc/sourceDesc/msDesc/physDesc/bindingDesc/binding/p").map(&:text).uniq.join ";"
  # manuscript_link
  # other_info
  other_info = extract_other_info doc
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
  # layout

  {
    source_catalog_or_lot_number: source_catalog_or_lot_number,
    titles: titles,
    authors: authors,
    dates: dates,
    artists: artists,
    scribes: scribes,
    languages: languages,
    materials: materials,
    places: places,
    manuscript_binding: manuscript_binding,
    other_info: other_info,
    provenance: provenance,
  }
end

#
# tei_file = ARGV.shift
#
# data = extract_data open tei_file
#
# puts data
