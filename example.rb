require 'pp'
require_relative "lib/pubchem"

reader = Reader.new
reader.read('xml/compound_sample.xml')
reader.read('xml/substance_sample.xml')
reader.save("xml/names.xml",
            "xml/pubchem_substance_ids.xml",
            "xml/pubchem_compound_ids.xml")

# The first two terms match, the last one replaces a "1H"
# with a "2H", resulting in a non-match.

terms = [ "COC1=C(C=C2CC3=CC(=C(C=C3CC4=CC(=C(C=C4CC2=C1)OC(=O)C5=CC=NC=C5)OC)OC(=O)C6=CC=NC=C6)OC)OC(=O)C7=CC=NC=E9",
          "4-methoxy-1H-indole-3-carbaldehyde",
          "4-methoxy-2H-indole-3-carbaldehyde",
          "2-amino-4,5-dimethyl-1H-pyrrole-3-carbonitrile" ]

pp reader.match_list_of_names terms
pp reader.retrieve_compound_ids
pp reader.pubchem_substance_ids
pubchem = Pubchem.new

ids = reader.retrieve_substance_ids.map {|k,v| v}

pubchem.get_substance_ids(ids, "yay.zip")

puts "Do a happy dance!"
