# Pubchem image downloader

For getting all that juicy substance and compound data from Pubchem.

## Installation

`gem install pubchem`

## Usage

```ruby
pubchem = Pubchem.new

pubchem.get_ids([16,405], "~/yay.zip")

puts "Do a happy dance!"
```
