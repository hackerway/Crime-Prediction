d = csvread('pd911rc.csv');
d2 = csvread('pd911_lat_long.csv');

divs = 7;


xbin = round((max(d(:,1))-min(d(:,1)))/divs);
ybin = round((max(d(:,2))-min(d(:,2)))/divs);


xbin2 = round((max(d2(:,1))-min(d2(:,1)))/divs);
ybin2 = round((max(d2(:,2))-min(d2(:,2)))/divs);


%hist3(d, [xbin ybin])
hist3(d2, [xbin2 ybin2])