require_relative "lib/pubchem"

pubchem = Pubchem.new

pubchem.get_ids([16,405], "~/yay.zip")

puts "Do a happy dance!"
