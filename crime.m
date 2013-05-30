clear all
cd ~/Google' Drive'/School' 13'/Pattern' Recognition'/Crime' Project'/code


    % Gaussian Process
 %   addpath('~/Google Drive/School 13/Pattern Recognition/matlab_packages/pmtk3-1nov12/')    
  %  initPmtk3
    addpath('~/Google Drive/School 13/Pattern Recognition/matlab_packages/gpml-matlab-v3.2-2013-01-15/')
    startup;



d = csvread('pd911rc.csv');
d2 = csvread('pd911_lat_long.csv');

d2(:,1) = (d2(:,1)-mean(d2(:,1)))/std(d2(:,1));
d2(:,2) = (d2(:,2)-mean(d2(:,2)))/std(d2(:,2));

divs = 7;


xbin = round((max(d(:,1))-min(d(:,1)))/divs);
ybin = round((max(d(:,2))-min(d(:,2)))/divs);


xbin2 = round((max(d2(:,1))-min(d2(:,1)))/divs);
ybin2 = round((max(d2(:,2))-min(d2(:,2)))/divs);


%hist3(d, [xbin ybin])
hist3(d2, [xbin ybin]);


isnan(d2);

%%
d = csvread('pd911_main.csv');
idx_row = find(sum(d(:,4:end),2)>10);
idx_col = find(sum(d)>100);
d = d(idx_row,idx_col);

for i = 1:size(d,1)
    total = sum(d(i,:));
    for j = 1:size(d,2)
        d(i,j) = d(i,j)/total;
        
    end
end

minx = min(d);
maxx = max(d);
scalefacts = maxx-minx;
%for j=1:size(d,2),
%    d(:,j) = 2/scalefacts(j)*(d(:,j)-minx(j))+(-1);
%end
for j=1:size(d,2)
    x = d(:,j);
    d(:,j) = (x-mean(x))/std(x);
    
end




    names = {'row',' col ',' mjds_start ','DISTURBANCES','ARREST','MENTAL_HEALTH','BURGLARY','LIQUOR_VIOLATIONS','TRAFFIC_RELATED_CALLS','SUSPICIOUS_CIRCUMSTANCES','FALSE_ALARMS','TRESPASS','HAZARDS','MISCELLANEOUS_MISDEMEANORS','CAR_PROWL','SHOPLIFTING','RECKLESS_BURNING','PROSTITUTION','ACCIDENT_INVESTIGATION','PROPERTY_DAMAGE','OTHER_PROPERTY','AUTO_THEFTS','NARCOTICS_COMPLAINTS','PROWLER','THREATS_HARASSMENT','BIKE','PROPERTY__MISSING_FOUND','PERSON_DOWN_INJURY','NUISANCE_MISCHIEF','ASSAULTS','HARBOR_CALLS','PERSONS__LOST_FOUND_MISSING','ROBBERY','WEAPONS_CALLS','LEWD_CONDUCT','ANIMAL_COMPLAINTS','DRIVE_BY_NO_INJURY','FRAUD_CALLS','FAILURE_TO_REGISTER_SEX_OFFENDER','OTHER_VICE','HOMICIDE','VICE_CALLS','NUISANCE_MISCHIEF_'};


    ncov = 6;
    test_errs = zeros(size(names,2)-3,ncov);
    test_errs_summed = zeros(size(names,2)-3,ncov);
    %burglary = 7
    mean_guesses = zeros(size(names,2)-3,1);



for target=4:size(names,2)
    disp(target)
    y_idx = target;
    x_idx = [1:y_idx-1, y_idx+1:size(d,2)];

    X = d(:,x_idx);
    Y = d(:,y_idx);

    Xsum = sum(X,2);


    Xsum = 2/(max(Xsum)-min(Xsum))*(Xsum-min(Xsum))+(-1);


    trainSize = round(size(X,1)*2/3);
    randindex = randperm(size(X,1));

    Xtrain = X(randindex(1:trainSize),:);
    Xtest = X(randindex(trainSize+1:end),:);

    Xsumtrain = Xsum(randindex(1:trainSize),:);
    Xsumtest = Xsum(randindex(trainSize+1:end),:);



    ytrain = Y(randindex(1:trainSize));
    ytest = Y(randindex(trainSize+1:end));

    % reduced data set for minimization.


    
    min_idx = 1:500;




    Ncg = 50;                                 
    sdscale = 0.5;   
    D = size(X,2);
    L = rand(D,1);
    ell = .9;
    sf = 2;

    cp  = {@covPoly,6}; c = 2; hypp = log([c;sf]);   % third order poly
    %cga = {@covSEard};   hypga = log([L;sf]);       % Gaussian with ARD
    cgi = {'covSEiso'};  hypgi = log([ell;sf]);    % isotropic Gaussian
    cgu = {'covSEisoU'}; hypgu = log(ell);   % isotropic Gauss no scale
    %cra = {'covRQard'}; al = 2; hypra = log([L;sf;al]); % ration. quad.
    cri = {@covRQiso};         al=2; hypri = log([ell;sf;al]);   % isotropic
    cm  = {'covMaterniso',3}; hypm = log([ell;sf]);  % Matern class q=3
    cnn = {'covNNone'}; L = rand(1,1);hypnn = log([L;sf]);           % neural network
    %cpe = {'covPeriodic'}; om = 2; hyppe = log([ell;om;sf]); % periodic

    %cov_funcs = {cp, cga, cgi, cgu, cri, cm, cnn};
    cov_funcs = {cp,cgi, cgu, cri, cm, cnn};

    %hyp0_covs = {hypp, hypga, hypgi, hypgu, hypri, hypm, hypnn};
    hyp0_covs = {hypp, hypgi, hypgu, hypri, hypm, hypnn};

    %test_errs = zeros(size(cov_funcs));
    %test_errs_summed = zeros(size(cov_funcs));
    for i = 1:size(cov_funcs,2)
        covrbf = cov_funcs{i};
        disp(covrbf)
        hyp0.cov = hyp0_covs{i};
        meanrbf = {@meanZero};
        hyp0.mean = [];
        lik = 'likGauss';
        hyp0.lik  = log(0.2);
        inf = 'infExact';

        hyp = minimize(hyp0,'gp', -Ncg, inf, meanrbf, covrbf, lik, Xtrain(min_idx,:), ytrain(min_idx,:));
        [ymuPred, ys2] = gp(hyp, inf, meanrbf, covrbf, lik, Xtrain, ytrain, Xtest);

        test_errs(i,target-3) = sum((ymuPred-ytest).^2);

        %hyp = minimize(hyp0,'gp', -Ncg, inf, meanrbf, covrbf, lik, Xsumtrain(min_idx,:), ytrain(min_idx,:));
        %[ymuPred, ys2] = gp(hyp, inf, meanrbf, covrbf, lik, Xsumtrain, ytrain, Xsumtest);

        %test_errs_summed(i,target-3) = sum((ymuPred-ytest).^2);



    end

   mean_guess = mean(ytest)*ones(size(ytest));

    mean_guesses(target) = sum((mean_guess-ytest).^2);
end


%%
ytrainMean = d(randindex(1:trainSize),:);
ytest = d(randindex(trainSize+1:end),:);
p = mean(ytrainMean);

ytrainPred = [];
for i = 1:size(ytestMean,1)
   ytrainPred = [ytrainPred; p];
end

meanSSE = sum((ytrainPred-ytest).^2);

csvwrite('test_errs_summed.csv', test_errs_summed);
csvwrite('test_errs.csv', test_errs);
csvwrite('mean_errs.csv', meanSSE);
csvwrite('sd.csv', sD);



total = sum(d(:,4:end));

%%

d = d(:,4:end);
cor_matrix = zeros(40,40);


for i = 1:40
    cor_matrix(i,:) = corr(d(:,i),d);
    
    
end



% time, 

% renormalize based on crime/total crimes