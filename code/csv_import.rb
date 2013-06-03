require 'mysql'
require 'csv'
$db = Mysql.new 'localhost', 'root', 'password', 'crime'#SQLite3::Database.open "crime.db"

file = ARGV[0]
table_name = ARGV[1]
drop = ARGV[2]



def table_from_csv(file, table_name, drop = false)
	if drop
		sql = $db.prepare("DROP TABLE IF EXISTS #{table_name}") 
		sql.execute
	end
	
	data = []
	CSV.foreach(file) do |row|
		data << row
	end

	puts "data loaded for #{table_name}, creating table."	

	header = data[0]
	
#	puts "header names = \n#{header.inspect}\n"
	
	# Alter column names if there are duplicates. Notify if this happens.
	# Also remove ' ' and / characters:
	column_names_changed = false
	header.each do |col|
		col.gsub!(" ","_")
		col.gsub!("/","_")
			
		if header.count(col) != 1
			header[header.index(col)] += "X"		
			column_names_changed = true
		end
	end
	puts "Columns names changed due to duplicates" if column_names_changed
	

	
	create_statement = "CREATE TABLE #{table_name} ("
	header.each do |col|
		create_statement += col+" BLOB,"
	end
	
	# Delete trailing comma, add closing parens
	create_statement = create_statement[0...-1]+")"
	
	sql = $db.prepare(create_statement)
	sql.execute
	
	# To add into a table we need a template entry composed of question marks.
	template = "("+"?,"*(header.length-1)+"?)"
	
	data[1..-1].each do |row|
		sql = $db.prepare("INSERT INTO #{table_name} VALUES #{template}")
		sql.execute row
	end
	puts "#{table_name} created."
end
	
	





table_from_csv(file,table_name, drop)