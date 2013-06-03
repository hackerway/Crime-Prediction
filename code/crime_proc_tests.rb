require 'sqlite3'
require './crime_proc_funcs'
require "./offense_type"
$db = SQLite3::Database.open "../crime.db"

require 'sqlite3'
require './crime_proc_funcs'
$db = SQLite3::Database.open "../crime.db"

# Areas. Probably better done with hardcoded boundaries.

# Create area table. Tables with longitude/latitude information:
# codeViol, pr_inc, neighborhood, pd911
tables = ["codeViol", "pr_inc", "neighborhood", "pd911"]
lats = []
longs = []


puts "calculating latitude and longitude ranges. . ."

tables.each do |t|
	lats += $db.execute("SELECT MAX(latitude), MIN(latitude) FROM #{t}")[0]
	longs += $db.execute("SELECT MAX(longitude), MIN(longitude) FROM #{t}")[0]
end

# queries are returned as strings, convert here to fixnum:
lats = lats.map(&:to_f)
longs = longs.map(&:to_f)


max_lat = lats.max
min_lat = lats.min
max_long = longs.max
#min_long = longs.min #This one is fucked up. 
min_long = -122.434761

puts "done.\n"


puts "creating areas. . ."
$areas = create_areas(min_lat, min_long, max_lat, max_long, 0.17)
puts "done."

puts "Creating area hash. . ."

puts "done.\n"



def sqlite_insert_TEST()
	$db.execute("DROP TABLE IF EXISTS test")
	$db.execute("CREATE TABLE test (id, id2, id3)")

	t = [[1,2,3],[4,5,6], [5,6,7], [8,9,10]]


	sqlite_insert("test", t)
end


def create_areas_TEST()
	puts create_areas(0.0,10.0,0.0,20.0,1.0,1.0,1.0).inspect
end


def find_areasID_TEST()


	test1 = $db.execute("SELECT minLat, minLong FROM areas WHERE areaID = '1_10'");

	count = 1 	
	b1 = Time.new	
	while count <500
		puts count if count%100 == 0
		# find_areasID(test1[0][0]+0.0001,test1[0][1]+0.0001,$areas)

		count += 1
	end
	a1 = Time.new
	
	
	count = 1 	
	b2 = Time.new	
	while count <500
		puts count if count%100 == 0
		 find_areaID(test1[0][0]+0.0001,test1[0][1]+0.0001)

		count += 1
	end
	a2 = Time.new
	
	
	
	
	puts "sql selects took #{a2-b2}"
	puts "custom function took #{a1-b1}"
end


def verify_neigh_areaID()
	mismatches =  $db.execute("SELECT COUNT(*) FROM nh_proc JOIN areas USING (areaID) WHERE
		areas.minLat > nh_proc.lat OR
		areas.maxLat < nh_proc.lat OR
		areas.minLong > nh_proc.long OR
		areas.maxLong < nh_proc.long")[0][0]
	if mismatches == 0
		puts "areaID's between areas and nh_proc tables match" 
	else 
		puts "There are #{mismatches} between areas and nh_proc table areaIDs"
	end
	
	mismatches =  $db.execute("SELECT COUNT(*) FROM cvs_proc JOIN areas USING (areaID) WHERE
		areas.minLat > cvs_proc.lat OR
		areas.maxLat < cvs_proc.lat OR
		areas.minLong > cvs_proc.long OR
		areas.maxLong < cvs_proc.long")[0][0]
	if mismatches == 0
		puts "areaID's between areas and cvs_proc tables match" 
	else 
		puts "There are #{mismatches} between areas and cvs_proc table areaIDs"
	end
		
	

end

def offense_type_TEST()
	offense_type = offense_type()
	qs = $db.execute("SELECT DISTINCT offense_type FROM pr_inc")
	qs.each do |q|
		return "offense type #{q[0]} not found" if offense_type[q[0]].nil?
	end
	return "offense type dict looks ok."


end
#puts verify_neigh_areaID()
#puts find_areaID(47.731918948,-122.347471854)
#puts date_mjd("1/4/2004")
puts offense_type_TEST()





__END__
areas = {1_1 => [0,0,1,1],
	1_2 => [0,0,1,1],
	1_3 => [0,1,1,2],
	1_4 => [0,2,1,3],
	1_5 => [0,3,1,4],
	2_1 => [1,0,2,1],
	2_2 => [1,1,2,2],
	2_3 => [1,2,2,3],
	2_4 => [1,3,2,4],
	2_5 => [1,4,2,5],
	3_1 => [2,0,3,1],
	3_2 => [2,1,3,2],
	3_3 => [2,2,3,3],
	3_4 => [2,3,3,4],
	3_5 => [2,4,3,5],
	4_1 => [3,0,4,1],
	4_2 => [3,1,4,2],
	4_3 => [3,2,4,3],
	4_4 => [3,3,4,4],
	4_5 => [3,4,4,5]}
	
	
	
puts find_areaId(0.5,0.5,areas)
	