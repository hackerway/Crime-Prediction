require 'sqlite3'
require './crime_proc_funcs'
require './offense_type'
$db = SQLite3::Database.open "./crime.db"

########################### Define areas. 
# Probably better done with hardcoded boundaries.

def areaTab()
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
	puts "lat ranges from #{min_lat} to #{max_lat}.\n long ranges from #{min_long} to #{max_long}"
	puts "done.\n"



	puts "creating areas hash. . ."
	areas = create_areas(min_lat, min_long, max_lat, max_long, 0.17)
	puts "done."

	puts "Inserting values into areas"
	$db.execute("DROP TABLE IF EXISTS areas")
	$db.execute("CREATE TABLE areas (areaId, row, col, minLat, minLong, maxLat, maxLong)")
	sqlite_insert("areas",areas)
	puts "done.\n"

end
########################### Process tables.
# Convention: *_proc
def neighTab()
	# Neighborhood

	puts "populating nh_proc table. . ."
	$db.execute("DROP TABLE IF EXISTS nh_proc")
	$db.execute("CREATE TABLE nh_proc (featID INTEGER, areaID TEXT, row INTEGER
	col INTEGER feat TEXT, 
		lat REAL,long REAL)")
	nhs = $db.execute("SELECT city_feature, latitude, longitude FROM neighborhood")
	id = 1000
	placeholder = "(?,?,?,?,?,?,?)"
	(0...nhs.length).each do |i|
		lat = nhs[i][1]
		long = nhs[i][2]
		feat = nhs[i][0]
		areaID = find_areaID(lat,long)
		row,col = areaID.split(/_/).map{|i| i.to_i}
		$db.execute("INSERT INTO nh_proc VALUES #{placeholder}",
		[id, areaID, row,col,feat, lat, long])
		id += 1

	end
	puts "done.\n"
end

# Codeviol

def cvsTab()
	puts "populating cvs_proc table. . ."

	$db.execute("DROP TABLE IF EXISTS cv_proc")
	$db.execute("CREATE TABLE cv_proc (
		cvID INTEGER, 
		areaID TEXT,
		row INTEGER,
		col INTEGER, 
		case_group TEXT, 
		lat REAL, 
		long REAL, 
		mjd REAL)")
	cvs = $db.execute("SELECT 
		case_group, 
		latitude, 
		longitude, 
		date_case_created 
	FROM codeViol WHERE
		case_group IS NOT NULL AND 
		latitude IS NOT NULL AND 
		longitude IS NOT NULL AND
		date_case_created IS NOT NULL")
	total = cvs.size
	id = 1000
	placeholder = "(?,?,?,?,?,?,?,?)"
	(0...cvs.length).each do |i|
	
		lat = cvs[i][1]
		long = cvs[i][2]
		case_group = cvs[i][0]
		mjd = date_mjd(cvs[i][3])
		areaID = find_areaID(lat,long)
		row, col = areaID.split(/_/).map{|i| i.to_i}
	
		#puts "#{[id, find_areaID(lat,long), case_group, lat, long, mjd].inspect} = #{cvs[i][-1]}"
		$db.execute("INSERT INTO cv_proc VALUES #{placeholder}", 
			[id, areaID, row, col, case_group, lat, long, mjd])
		id += 1
	
	
		puts "\t#{(id-1000)*100/total} percent done. . ." if ((id-1000)*100.0/total)%1 == 0
	end
	puts "done.\n"
end

# pr inc

def prTab()
	puts "populating pr_proc table. . ."
	offense_type = offense_type()
	pr_incs = $db.execute("SELECT 
		Latitude, 
		Longitude, 
		Hundred_Block_Location, 
		Zone_Beat,
		Census_Tract_2000, 
		Occurred_Date_or_Date_Range_Start, 
		Occurred_Date_Range_End,
		Date_Reported, 
		Summarized_Offense_Description, 
		Offense_Type, 
		RMS_CDW_ID
	FROM pr_inc WHERE
		Offense_Type IS NOT NULL AND
		Occurred_Date_or_Date_Range_Start IS NOT NULL AND
		Latitude IS NOT NULL AND
		Longitude IS NOT NULL AND 
		Longitude != \"-127.390661925\"")
	pr_id = 1000
	$db.execute("DROP TABLE IF EXISTS pr_proc")
	$db.execute("CREATE TABLE pr_proc (
		prId INTEGER, 
		areaID TEXT, 
		row INTEGER, 
		col INTEGER,
		latitude REAL,
		longitude REAL, 
		hundred_block TEXT, 
		zone TEXT, 
		census TEXT, 
		mjd REAL, 
		reported_delay REAL, 
		desc TEXT, 
		off_type TEXT, 
		proc_off_type TEXT)")
	total = pr_incs.size
	pr_incs.each do |pr|
		id = pr_id
		lat = pr[0]; raise "RMS #{pr[-1]} has invalid lat" if lat.nil?
		long = pr[1];  raise "RMS #{pr[-1]} has invalid long" if long.nil? 
		areaID = find_areaID(lat,long)
		row,col = areaID.split(/_/).map{|i| i.to_i}
		hbl = pr[2]
		zone= pr[3]
		census = pr[4]
		occur = (pr[6].nil?) ? date_mjd(pr[5]) : (date_mjd(pr[5])+date_mjd(pr[6]))/2.0
		delay = date_mjd(pr[7]) - occur
		desc = pr[8]
		off_type = pr[8]
		proc_off_type = offense_type[pr[9]]
		raise "pr[9] not found in dict" if proc_off_type.nil?
	
		placeholder = "("+"?,"*13+"?)"
		$db.execute("INSERT INTO pr_proc VALUES #{placeholder}", 
			[id, areaID, row, col,lat, long, hbl, zone, census, occur, delay, desc, off_type, 
				proc_off_type])
		pr_id += 1
		puts "\t #{id} of #{total} #{(pr_id-1000)*100/total} percent done. . ." if ((pr_id-1000)*100.0/total)%1== 0 
	end		
	puts "done."
end

#pd911 table

def pd911Tab()
	puts "Creating pd911_proc."
# keep groupings as is, cap at <500.
	pd911 = $db.execute("SELECT 
		Event_Clearance_Group, 
		Latitude, Longitude, 
		Census_Tract, 
		Hundred_Block_Location, 
		Zone_Beat, 
		Event_Clearance_Date 
	FROM pd911 WHERE
		Event_Clearance_Group IS NOT NULL AND
		Latitude IS NOT NULL AND
		Longitude IS NOT NULL AND
		Event_Clearance_Date IS NOT NULL AND
		Event_Clearance_Group IS NOT NULL AND
		Census_tract IS NOT NULL")
	pd911_id = 1000
	$db.execute("DROP TABLE IF EXISTS pd911_proc")
	$db.execute("CREATE TABLE pd911_proc (
		pd911Id INTEGER, 
		desc TEXT, 
		latitude REAL,
		longitude REAL, 
		areaID INTEGER,
		row INTEGER,
		col INTEGER,
		zone TEXT, 
		census TEXT, 
		hundred_block TEXT, 
		mjd REAL)")
	total = pd911.size
	pd911.each do |pd|
		id = pd911_id
		desc = pd[0]
		lat = pd[1]
		long = pd[2]
		areaID = find_areaID(lat,long)	
		row,col = areaID.split(/_/).map{|i| i.to_i}	
		zone = pd[5]
		census = pd[3]
		hbl = pd[4]
		dt = date_mjd(pd[6])
		
		placeholder = "("+"?,"*10+"?)"
		$db.execute("INSERT INTO pd911_proc VALUES #{placeholder}",
			[id,desc,lat,long,areaID,row,col,zone,census,hbl,dt])
		puts "\t #{id-1000} of #{total} done" if (id-1000)%10000 == 0
		pd911_id+=1
	end
	puts "done"
end

def timeGrid(tables, interval)
	min_mjd, max_mjd = getTimeRange(["cv_proc", "pr_proc", "pd911_proc"])	
	mjds = (min_mjd..max_mjd).step(interval).to_a
	id = 1000
	
	$db.execute("DROP TABLE IF EXISTS mjds")
	$db.execute("CREATE TABLE mjds (mjd_id INTEGER, mjd_start INTEGER, mjd_end)")
	(0..mjds.length).each do |i|
		$db.execute("INSERT INTO mjds VALUES (?,?,?)", id,mjds[i], mjds[i+1])
		id += 1
	end
end

def addTimeGridCols(tbls)
	tbls.each do |tbl|
		$db.execute("ALTER TABLE #{tbl} ADD COLUMN mjd_id INTEGER")		
		$db.execute("UPDATE #{tbl} SET mjd_id = 
			(SELECT mjd_id FROM mjds WHERE 
			mjds.mjd_start <= #{tbl}.mjd AND
			mjds.mjd_end > #{tbl}.mjd)")
		puts "#{tbl} updated to include time cell"
	end
	
end

def pruneAreas(in_tables)
	# Detects whether or not each areaID has within it a data object at any point.
	sql_cmd = "SELECT DISTINCT areaID FROM ("
	in_tables.each do |t|
		if t == in_tables[-1]
			sql_cmd += "SELECT areaID FROM #{t})"
		else
			sql_cmd += "SELECT areaID FROM #{t} UNION "
		end
	end 
	$db.execute("DELETE FROM areas WHERE areaID NOT IN (#{sql_cmd})")
end

tbl_params = {
	'pr' => {
		'tbl' => 'pr_proc',
		'src_col' => 'proc_off_type',
		'a_range' => 2,
		'time_range' => 4
	},
	'cv' => {
		'tbl' => 'cv_proc',
		'src_col' => 'case_group',
		'a_range' => 3,
		'time_range' => 90
	},
	'pd911' => {
		'tbl' => 'pd911_proc',
		'src_col' => 'desc',
		'a_range' => 2,
		'time_range' => 4
	}	
}

tbl_params.each do |t,v|
	v['src_cats'] = $db.prepare("SELECT DISTINCT #{v['src_col']} 
		FROM #{v['tbl']}").map{|c| c[0]}
	v['tgt_cols'] = v['src_cats'].map{|c| noSpecial(c) + "_#{v['tbl']}"}
end


	#	'src_cats' => $db.prepare("SELECT DISTINCT proc_off_type FROM pr_proc"
tgt_params = 	{
	'target_mjd_step' => 4,
	'nsamp' => 5  # out of 1,000,000
	}
	


def main_table(tbl_params, tgt_params)
	puts "Creating main table. . ."
	$db.execute("DROP TABLE IF EXISTS main")
	$db.execute("CREATE TABLE main (
		main_id INTEGER, 
		areaID TEXT, 
		row INTEGER,
		col INTEGER,
		mjd_start INTEGER
		)")
		
	# populate areaID and time range values. Add columns for values one at a time.
	areas = $db.execute("SELECT areaID from areas").map{|a| a[0]}
	mjd_starts = $db.execute("SELECT mjd_start FROM mjds").map{|m| m[0]}
	main_id = 1000	
	samp_freq = tgt_params['nsamp']*1000000/(areas.length*mjd_starts.length)
	
	expected = (areas.length*mjd_starts.length*samp_freq/1000000.0).floor
	
	puts "\tPopulating ids, expect #{expected} samples. . ."
	
	insert_string = "INSERT INTO main VALUES "
	areas.each do |a|
		mjd_starts.each do |m|
			if samp_freq >= rand(1000000)
				row,col = a.split(/_/).map{|i| i.to_i}
				insert_string += "(#{main_id}, '#{a}', #{row}, #{col},#{m}),"
				
				main_id += 1
			end
				

		end
	end

	$db.execute(insert_string[0...-1])
	
	
	tbl_params.each do |k,v|
		(0...v['tgt_cols'].length).each do |i|
			puts "tgt_col = #{v['tgt_cols'][i]}"
			$db.execute("ALTER TABLE main ADD COLUMN #{v['tgt_cols'][i]} INTEGER")
			sql_cmd = "UPDATE main SET #{v['tgt_cols'][i]} =
				(SELECT COUNT(*) FROM #{v['tbl']} WHERE 
					#{v['src_col']} == '#{v['src_cats'][i]}' AND 
					#{v['tbl']}.mjd < main.mjd_start AND
					#{v['tbl']}.mjd > (main.mjd_start - #{v['time_range']}) AND
					#{v['tbl']}.row < main.row + #{v['a_range']} AND					
					#{v['tbl']}.row >= main.row - #{v['a_range']} AND					
					#{v['tbl']}.col < main.col + #{v['a_range']} AND					
					#{v['tbl']}.col >= main.col - #{v['a_range']}										
					)"
			puts "\t\t\t#{v["tgt_cols"][i]} added."
			#p $db.prepare("SELECT * FROM main").columns.inspect
			$db.execute(sql_cmd)
		end
	#	 UPDATE main SET NUISANCE_MISCHIEF__pd911_proc = (SELECT COUNT(*) FROM pd911_proc WHERE pd911_proc.mjd < main.mjd_start AND pd911_proc.areaID == main.areaID);
	
	end
	
end

#cvsTab()
#pd911Tab()
#neighTab()
#prTab()
#pruneAreas(['pr_proc', 'cv_proc', 'nh_proc', 'pd911_proc'])
#timeGrid(['pr_proc', 'cv_proc', 'pd911_proc'],4)
#addTimeGridCols(['cv_proc','pr_proc','pd911_proc'])
#main_table(tbl_params, tgt_params)

$db.execute(
	'DELETE FROM pd911_proc_filt WHERE 
		latitude < 47.54067 OR 
		latitude > 47.69898 OR
		longitude < -122.3725 OR
		longitude > -122.2901 OR
		mjd < 55402.73 OR
		mjd > 56342.02')

def pd911_main()
	# create a table by zone.
	cols_src = $db.execute("SELECT DISTINCT(desc) FROM pd911_proc_filt").map{|m| m[0]}
	cols_dest = cols_src.map{|c| noSpecial(c)}


	sql = "CREATE TABLE pd911_main (row INTEGER, col INTEGER, mjds_start REAL"
	cols_dest.each do |c|
		sql += "," + c
	end

	$db.execute("DROP TABLE IF EXISTS pd911_main")
	$db.execute(sql + ")")
	
	nonNullClause = ' WHERE col IS NOT NULL AND row IS NOT NULL AND mjd IS NOT NULL AND desc IS NOT NULL'
	
	min,max = $db.execute("SELECT MIN(mjd), MAX(mjd) FROM pd911_proc_filt" + nonNullClause)[0]
	rowsMin, rowsMax = $db.execute("SELECT MIN(row), MAX(row) FROM pd911_proc_filt" + nonNullClause)[0]
	colsMin, colsMax = $db.execute("SELECT MIN(col), MAX(col) FROM pd911_proc_filt" + nonNullClause)[0]

	timeStep = 45
	areaStep = 3


	# Time period: 60 interval starting with mjd
	numCols = $db.prepare("SELECT * FROM pd911_main").columns.length

	m = min

	zones = $db.execute("SELECT DISTINCT zone FROM pd911_proc_filt").map{|m| m[0]}
	

	
	
	
	start = Time.new()
	numbdone = 0
	total = ((rowsMax-rowsMin) * (colsMax-colsMin)* (max-min)/(timeStep*areaStep**2)).round
	(min..max).step(timeStep) do |m|
		(rowsMin..rowsMax).step(areaStep) do |r|
			(colsMin..colsMax).step(areaStep) do |c|
				sql = ""
				(0...cols_src.length).each do |i|
				
					# form sql statement
					sql += " UNION ALL SELECT COUNT(*) FROM pd911_proc_filt 
					WHERE 
						row IS NOT NULL AND 
						col IS NOT NULL AND
						mjd IS NOT NULL AND 
						desc IS NOT NULL AND
						row >= #{r} AND
						row < #{r+areaStep} AND
						col >= #{c} AND
						col < #{c+areaStep} AND 
						mjd >= #{m} 
						AND mjd < #{m+60} AND
						desc = '#{cols_src[i]}'"
				end
				
			# remove leading 'union all'
			sql = sql[10..-1]
	
			# create insert:
			data = $db.execute(sql).map{|m| m[0]}
		
				sql = "INSERT INTO pd911_main VALUES(#{r}, #{c}, #{m}"
				data.each do |d|
					sql += ",#{d}"
				end
				sql += ")"
				puts sql
				$db.execute(sql)
				
				
				numbdone += 1
				timeleft = (Time.new-start)*total / numbdone
				puts "#{numbdone} of #{total} done, #{(timeleft/60).round/60} hours, #{(timeleft/60).round%60} minutes remaining"
			end
		end
	end
	puts 'populating'
	
	
	
	
end





pd911_main()
__END__


#SELECT COUNT(*) FROM pd911_proc WHERE zone IS NOT NULL AND mjd IS NOT NULL AND desc IS NOT NULL AND zone == 'N1' AND mjd >= 55053.92152777778 AND mjd < 55113.92152777778 AND desc = 'NARCOTICS COMPLAINTS' UNION ALL SELECT COUNT(*) FROM pd911_proc



#puts '################ This might take a while. Have you turned off disk hibernation?'
#areaTab()
#neighTab()
#cvsTab()
#prTab()	
#pd911Tab()
#pruneAreas(['pr_proc', 'cv_proc', 'nh_proc', 'pd911_proc'])
#timeGrid(['pr_proc', 'cv_proc', 'pd911_proc'],4)
#addTimeGridCols(['cv_proc'])




