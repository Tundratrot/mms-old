class Material < ActiveRecord::Base
  validates :category, presence:true,
            length: { minimum: 1 }

  include PgSearch
  pg_search_scope :search, against: [:category, :subcategory, :measurements, :product, :product_number, :product_description, :uom, :vendor],
  using: {tsearch: {dictionary: "english"}},
  ignoring: :accents
  
  def self.text_search(query)
    if query.present?
      # search(query)

       rank = <<-RANK
         ts_rank(to_tsvector(category), plainto_tsquery(#{sanitize(query)})) + 
         ts_rank(to_tsvector(product_description), plainto_tsquery(#{sanitize(query)}))  
       RANK

      where("((category || ' ' || product ) @@ :q) OR \
      (( category || ' ' || measurements ) @@ :q) OR \
      (( category || ' ' || product_description ) @@ :q) OR \
      (( category || ' ' || vendor ) like :q) OR \
      (( measurements || ' ' || product ) @@ :q) OR \
      (( measurements || ' ' || product_description ) @@ :q) OR \
      (( measurements || ' ' || vendor ) @@ :q) OR \
      (( product || ' ' || product_description ) @@ :q) OR \
      (( product || ' ' || vendor ) @@ :q) OR \
      (( product_description || ' ' || vendor ) @@ :q) OR \
      (( category || ' ' || subcategory || ' ' || measurements || ' ' || product || ' ' || product_number || ' ' || product_description || ' ' || uom || ' ' || vendor ) @@ :q) OR \
      category @@ :q OR subcategory @@ :q OR measurements @@ :q OR product @@ :q OR product_number @@ :q OR product_description @@ :q OR uom @@ :q OR vendor @@ :q", q: query).order("#{rank} desc")

     else
       default_scoped
     end
   end
   

  def self.to_csv (options = {})
    CSV.generate(options) do |csv|
    csv << column_names
       all.each do |material|
          csv << material.attributes.values_at(*column_names)
       end
    end
  end
  
  
  def self.import(file)
    spreadsheet = open_spreadsheet(file)
    header = spreadsheet.row(1)
    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      material = find_by_id(row["id"]) || new
      material.attributes = row.to_hash
      material.save!
    end
  end
  
  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)
    when ".csv" then Roo::Csv.new(file.path, nil, :ignore)
    when ".xls" then Roo::Excel.new(file.path, nil, :ignore)
    when ".xlsx" then Roo::Excelx.new(file.path, nil, :ignore)
    else raise "Unknown file type: #{file.original_filename}"
    end
  end
  
  def self.searchable
  end
    
end

