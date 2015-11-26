require 'set'
require 'nokogiri'
require 'fuzzystringmatch'
require 'ox'

class Reader

  attr_accessor :names,
                :pubchem_substance_ids,
                :pubchem_compound_ids

  def initialize(names_filename=nil,
                 pubchem_substance_ids_filename=nil,
                 pubchem_compound_ids_filename=nil)

    @fuzzy_matcher = FuzzyStringMatch::JaroWinkler
                     .create( :native )

    return if initialize_from_files( names_filename,
                                     pubchem_substance_ids_filename,
                                     pubchem_compound_ids_filename )

    @names = Hash.new { |h,k| h[k] = Set.new }

    @pubchem_substance_ids = Hash.new { |h,k| h[k] = Set.new }
    @pubchem_compound_ids = Hash.new  { |h,k| h[k] = Set.new }

  end

  def initialize_from_files(names_filename,
                            pubchem_substance_ids_filename,
                            pubchem_compound_ids_filename)

    filenames = [ names_filename,
                  pubchem_substance_ids_filename,
                  pubchem_compound_ids_filename ]

    return nil unless filenames.any?
    raise "Both filenames required" unless filenames.all?

    @names = Ox.load_file(names_filename)
    @pubchem_substance_ids = Ox.load_file(pubchem_substance_ids_filename)
    @pubchem_compound_ids = Ox.load_file(pubchem_compound_ids_filename)

  end

  def save(names_filename,
           pubchem_substance_ids_filename,
           pubchem_compound_ids_filename)

    Ox.to_file(names_filename, @names, indent: 0)
    Ox.to_file(pubchem_substance_ids_filename, @pubchem_substance_ids, indent: 0)
    Ox.to_file(pubchem_compound_ids_filename, @pubchem_compound_ids, indent: 0)

  end

  def read(xml_filepath, type: nil)

    filepath = File.basename(xml_filepath)
    if type.nil? and filepath.downcase.start_with? "compound"
      type = :compound
    elsif type.nil? and filepath.downcase.start_with? "substance"
      type = :substance
    else
      raise "Cannot infer pubchem type"
    end

    f = File.open(xml_filepath)
    doc = Nokogiri::XML(f)
    f.close
    @current_type = type.to_s
    case type
    when :compound
      doc.css("PC-Compounds PC-Compound").each do |compound|
        self.parse_compound(compound)
      end
    when :substance
      doc.css("PC-Substances PC-Substance").each do |substance|
        self.parse_substance(substance)
      end
    else
      raise "Unknown type"
    end

  end

  def parse_compound(compound)

    @pubchem_id = compound.css("PC-Compound_id
                                PC-CompoundType
                                PC-CompoundType_id
                                PC-CompoundType_id_cid").text.to_i

    compound.css("PC-Compound_props").each do |property|
      self.parse_property(property)
    end

  end

  def parse_substance(substance)


    @pubchem_id = substance.css("PC-Substance_sid
                                 PC-ID
                                 PC-ID_id").text.to_i

    substance.css("PC-Substance_synonyms
                   PC-Substance_synonyms_E").each do |substance_synonym|
      self.add_name(substance_synonym.text)
    end

  end

  def parse_property(property)

    property.css("PC-InfoData").each do |info_data|
      parse_info_data(info_data)
    end

  end

  def parse_info_data(info_data)

    urn_label = info_data.css("PC-InfoData_urn
                               PC-Urn
                               PC-Urn_label").first.text
    name = nil
    case urn_label
    when "SMILES"
      name = info_data.css("PC-InfoData_value
                            PC-InfoData_value_sval").first.text
    when"IUPAC Name"
      name = info_data.css("PC-InfoData_value
                            PC-InfoData_value_sval").first.text
    end

    self.add_name(name)
  end

  def add_name(name)
    return if name.nil? || name.empty?

    # Speed up lookups with sorted names
    @names[self.short_code(name)].add name

    if @current_type == "substance"
      @pubchem_substance_ids[name].add @pubchem_id
    elsif @current_type == "compound"
      @pubchem_compound_ids[name].add @pubchem_id
    else
      raise "Unknown substance"
    end

  end

  def fuzzy_name_lookup(lookup_name, threshold)

    closest_distance = 0.0
    closest_name = nil

    # Optimistically check for exact name match
    exact_match = self.short_code(lookup_name).include? lookup_name

    return @pubchem_ids[lookup_name] if exact_match
    return nil if threshold == 1.0

    @names[self.short_code(lookup_name)].each do |name|

      distance = @fuzzy_matcher.getDistance(lookup_name, name)

      if distance > closest_distance
        closest_name = name
        closest_distance = distance
      end

    end

    return closest_name if closest_distance > threshold

  end

  def match_list_of_names(names, threshold=0.99)
    @matched_names = names.inject({}) do |acc, name|
      acc[name] = self.fuzzy_name_lookup(name, threshold)
      acc
    end
  end

  def retrieve_ids(collection)
    msg = "@matched_names required, see #{self.class}#match_list_of_names"

    raise msg unless @matched_names

    @matched_names.inject({}) do |acc, name|
      input_name = name[0]
      matched_name = name[1]

      if matched_name
        ids = collection[matched_name]
        if ids.size > 1
          puts "WARNING: Multiple matching sets"
        end
        collection_id = collection[matched_name].first
        acc[input_name] = collection_id if collection_id
      end

      acc
    end
  end

  def retrieve_substance_ids
    self.retrieve_ids(@pubchem_substance_ids)
  end

  def retrieve_compound_ids
    self.retrieve_ids(@pubchem_compound_ids)
  end

  def short_code(name)
    name[0..2].downcase
  end

end
