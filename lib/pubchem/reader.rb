require 'set'
require 'nokogiri'
require 'fuzzystringmatch'
require 'ox'

class Reader

  attr_accessor :names, :pubchem_ids

  def initialize(names_filename=nil,
                 pubchem_ids_filename=nil,
                 pubchem_types_filename=nil)

    @fuzzy_matcher = FuzzyStringMatch::JaroWinkler
                     .create( :native )

    return if initialize_from_files( names_filename,
                                     pubchem_ids_filename,
                                     pubchem_types_filename )

    @names = Hash.new         { |h,k| h[k] = Set.new }
    @pubchem_ids = Hash.new   { |h,k| h[k] = Set.new }
    @pubchem_types = Hash.new { |h,k| h[k] = Set.new }

  end

  def initialize_from_files(names_filename,
                            pubchem_ids_filename,
                            pubchem_types_filename)

    filenames = [ names_filename,
                  pubchem_ids_filename,
                  pubchem_types_filename ]

    return nil unless filenames.any?
    raise "Both filenames required" unless filenames.all?

    @names = Ox.load_file(names_filename)
    @pubchem_ids = Ox.load_file(pubchem_ids_filename)

  end

  def save(names_filename,
           pubchem_ids_filename,
           pubchem_types_filename)

    Ox.to_file(names_filename, @names, indent: 0)
    Ox.to_file(pubchem_ids_filename, @pubchem_ids, indent: 0)
    Ox.to_file(pubchem_types_filename, @pubchem_types, indent: 0)

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

    # "IUPAC Name"
    # "SMILES"
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

    @pubchem_compound_ids[name].add @pubchem_id
  end

  def fuzzy_name_lookup(lookup_name, threshold=0.99)

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

    if closest_distance > 0.99

      id_matching_count = @pubchem_ids[closest_name].count
      if id_matching_count > 1
        # TODO: Think of a way of more intelligently choosing something that matches.
        print "Warning: randomly picking result out of: #{id_matching_count}"
      end

      return @pubchem_ids[closest_name].first

    end

  end

  def short_code(name)
    name[0..2].downcase
  end

end
