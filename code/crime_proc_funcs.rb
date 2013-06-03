require 'date'
def create_areas(min_lat, min_long, max_lat, max_long, sideLength, latConv = 69, longConv = 46.7)
# Returns array of square areas, with given boundaries, side length, and conversions.

# Procedure: Start at southwest corner, work across in rows, move up a row when east side 
# is reached. Convention for boxes: lat of SW, long of SW, lat of NE, long of NE.

# Each entry is: [id, row, col, minLat, minLong, maxLat, maxLong]
	latSide = sideLength/latConv
	longSide = sideLength/longConv
	
	areas = []
	
	latPos = min_lat + latSide/2
	longPos = min_long + longSide/2
	
	row = 1 
	col = 1
	
	while latPos < max_lat do 
		
		while longPos < max_long do 
			id = row.to_s + "_" + col.to_s
			areas << [id, row,col, latPos - latSide/2, longPos - longSide/2,
						latPos + latSide/2, longPos + longSide/2]
			longPos += longSide
			col +=1
		end
		
		latPos += latSide
		longPos = min_long+longSide/2
		col = 1
		row += 1
		
	end
	
	a_hash = {}
	areas.each do |a|
		a_hash[a[0]] = a[1..-1]
	end
	a_hash
end

def sqlite_insert(table, values, db =$db)
	# inserts array of arrays into given table.
	
	counter = 0
	placeholder = "(?" + ",?"*(values[values.keys[0]].length)+")" 
	values.each do |k,v|
		$db.execute("INSERT INTO #{table} VALUES #{placeholder}", [k]+v)
		counter += 1
		puts "\t#{counter} out of #{values.length} done. . . \n" if counter%5000 == 0

	end

end




def inBox?(query_coord, box_coord)
	query_coord[0] < box_coord[2] && query_coord[0] > box_coord[0] &&
		query_coord[1] < box_coord[3] && query_coord[1] > box_coord[1]

end
def find_areaID(lat,long)
	$db.execute("SELECT areaID FROM areas WHERE 
		minLat <= #{lat} AND 
		#{lat} < maxLat AND
		minLong <= #{long} AND
		#{long} < maxLong")[0][0]


end
def date_mjd(inString)
	# converts date to mjd
	begin
		dt = DateTime.strptime(inString, '%m/%d/%Y %I:%M:%S %p')
		ans = dt.mjd+dt.hour/24.0+dt.min/(24.0*60.0)+dt.sec/(24.0*60.0*60.0)
		
	rescue ArgumentError
		ans = Date.strptime(inString, "%m/%d/%Y").mjd
	end
	

end

def numbTable(high)
	numbs = (0..high)
	$db.execute("DROP TABLE IF EXISTS ns")
	$db.execute("CREATE TABLE ns (n INTEGER)")
	numbs.each do |n|
		$db.execute("INSERT INTO ns VALUES (#{n})")
	end
end

def adj_areas_string(areaID, sqs)
	row,col = areaID.split("_").map(&:to_i)
	rows,cols = (row-sqs..row+sqs), (col-sqs..col+sqs)
	
	ids = []
	
	rows.each do |r|
		cols.each do |c|
			ids << r.to_s+"_"+c.to_s
		end
	end

	# build concatenated list of results.
	ids.inject("") { |result, element| result + "'" + element+"'," }[0...-1]

end
x = adj_areas_string("324_30", 4)

def adjacent_Items(areaID, sqs, tgTable, tgCol, value, mjd=nil, range=nil)

	areas = adj_areas_string(areaID,sqs)
	sql = "SELECT COUNT(*) FROM #{tgTable} WHERE 
		#{tgCol} == '#{value}' AND
		areaID IN (#{areas})"
	if ![mjd,range].include?(nil)
		sql += " AND mjd >= #{mjd-range} AND mjd <= #{mjd}"
	end
	
	#puts sql
	$db.execute(sql)[0][0]
	
	
end

def noSpecial(inString)
	inString.gsub(/ /, "_").gsub(/,/, "").gsub(/\//,"_").gsub(/-/,"").gsub(/\(/,"").gsub(/\)/,"")
end

def getTimeRange(tbls)
	sqlMin = "SELECT MIN("
	sqlMax = "SELECT MAX("
	tbls.each do |t|
		sqlMin += "\n(SELECT MIN(mjd) FROM #{t}),"
		sqlMax += "\n(SELECT MAX(mjd) FROM #{t}),"
	end	
	sqlMin = sqlMin[0...-1]+")"
	sqlMax = sqlMax[0...-1]+")"
	
	min = $db.execute(sqlMin)[0][0].floor
	max = $db.execute(sqlMax)[0][0].ceil
	
	[min,max]

end

__END__
