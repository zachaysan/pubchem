require_relative "lib/pubchem"

reader = Reader.new
reader.read('xml/compound_sample.xml')
reader.read('xml/substance_sample.xml')
reader.save("xml/names.xml",
            "xml/pubchem_ids.xml",
            "xml/pubchem_types.xml")

# The first two terms match, the last one replaces a "1H" with a "2H",
# resulting in a non-match.
terms = [ "COC1=C(C=C2CC3=CC(=C(C=C3CC4=CC(=C(C=C4CC2=C1)OC(=O)C5=CC=NC=C5)OC)OC(=O)C6=CC=NC=C6)OC)OC(=O)C7=CC=NC=C7",
          "4-methoxy-1H-indole-3-carbaldehyde",
          "4-methoxy-2H-indole-3-carbaldehyde" ]

ids = terms.map {|term| reader.fuzzy_name_lookup(term) }.compact
require 'pry'
binding.pry

pubchem = Pubchem.new

pubchem.get_ids(ids, "~/yay.zip")

puts "Do a happy dance!"
