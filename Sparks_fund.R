#Setting Working Directory (directory where data files are available)
setwd("D:\\TP Data\\Tutorials\\UPGRAD PGDDA\\Course 1 - Introduction to Data Management\\Module 6 - Case Study")
#check if the working directory is properly set
getwd()
rm(list=ls())
#Loading data sets to R environment.

companies <- read.delim("companies.txt", sep = "\t", na.strings = c(""," "), stringsAsFactors = F)
# na.string parameter converts all null strings to NA values
# stringAsFactors parameter imports strings as string and not as factor variable.
# # Alternate Approach to read txt file: convert txt to csv and read as csv
# # companies <- read.csv(file="companies.csv", header = T, na.strings = c(""," "))

rounds2 <- read.csv(file="rounds2.csv", header = T, na.strings = c(""," "), stringsAsFactors = F)
#na.strings is used so that R can treat null strings present in dataset as NA



#=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=> 
#Checkpoint 1: Data Cleaning 1


# we will have to normalize the records present in the permalink columns of the datasets as the charachter case is different in both the files
# i) we will have to convert both the datasets to a unique case
# ii) also check there are no whitespaces

companies$permalink <- tolower(companies$permalink) # convert to lower case
companies$permalink <- trimws(companies$permalink) # remove leading and trailing whitespaces

rounds2$company_permalink <- tolower(rounds2$company_permalink) # convert to lower case
rounds2$company_permalink <- trimws(rounds2$company_permalink) # remove leading and trailing whitespaces


# >>>>>>>>>>>>>>> analysis of "companies.txt" <<<<<<<<<<<<<<<<<<<<<<
# Understanding the Dataset:
# Granularity Analysis of companies Dataset
# companies.csv file is a dimension file, hence we undertake the cleaning of dimension values first

length(companies$permalink) #66368
length(unique(companies$permalink)) #66368

# all the permalink values are unique, i.e. permalink is the unique key in the DF (the companies DF is @ permalink granularity)
# but we want to analyse how many unique companies are present in the companies DF

length(companies$name) #66368
length(unique(companies$name)) #66103
# No of Unique companies are less than the no of records in companies df


nrow(companies[which(is.na(companies$status)),]) 
# to check if there are any NA values in Status (There is none, all the records have the status flag)

nrow(companies[which(companies$status=="closed"),])
active_companies <- companies[which(companies$status != "closed"),]
# there are 6238 inactive companies("Closed"). For our analysis, Spark Funds will not
# prefer to invest in inactive companies, we subset for active companies

nrow(active_companies[which(is.na(active_companies$category_list)),])
# there are 2195 active companies who do not have their Category List mentioned
# These companies will be mapped to "Others" as main_sector in the analysis
# but we will not be performing any operations on main_sector "Others"
# hence we will skip these NA records,
final_companies <- active_companies[which(!is.na(active_companies$category_list)),]

# in the final companies dataset, we can see that that there some duplicate companiy names, 
# but have different permalinks, this is because their primary sector focus is different.

# there are also some companies, with same company name and same primary sector focus, but are 
# located in different geographies, and the investors for these companies will be different,
# hence we do not remove duplicate records.


final_companies <- final_companies[order(final_companies$name),]
# ordering the dataset ny name
rownames(final_companies)<-NULL
# setting default rownames to final_companies dataset


length(unique(final_companies$name))
# 57751 unique values are present after cleansing the data of DF
length(unique(final_companies$permalink))
# 57935



# >>>>>>>>>>>>>>> analysis of "rounds2.csv" <<<<<<<<<<<<<<<<<<<<<<
# Understanding the Dataset:
# Granularity Analysis of rounds2 Dataset

length(rounds2$company_permalink)
length(unique(rounds2$company_permalink))

# rounds2.csv is a fact file with investment data.
# We know that Spark Funds wants to invest in one of the 4 funding_type
# viz. seed, angel, venture, private_equity
# hence we will remove the records pertaining to all the other funding type
# captured in the rounds2 dataset, and rename it as sub_rounds2

sub_rounds2 <- rounds2[which(rounds2$funding_round_type %in% c("seed", "angel", "venture", "private_equity")),]


# in order to perform better analysis, we have to merge our fact file with our dimension file,
# for us to have a better understanding of the "data about data" (meta-data/dimension variables)

# before we perform merge, let us look at how many records of Investment details are available in rounds2 dataset
# for the no. of companies we have in our companies data set


nrow(final_companies) #57935
companies_to_rounds_match <- nrow(final_companies[final_companies$permalink %in% sub_rounds2$company_permalink,])
# 49516
# out of the 57935 companies present in the final_companies DF,
# investment information is available only for 49516 companies.

nrow(sub_rounds2) #94397
rounds_to_companies_match <- nrow(sub_rounds2[sub_rounds2$company_permalink %in% final_companies$permalink,])
# out of 94397 company_permalink values only 85217 have matching values in final_companies dataset
# for such records of rounds 2, we will not have any details available in final_companies dataset


# hence we remove these entries from our sub_rounds2 dataset and create a final_rounds2 dataset
final_rounds2 <- sub_rounds2[sub_rounds2$company_permalink %in% final_companies$permalink,]


master_frame <- merge(final_rounds2, final_companies, by.x="company_permalink", by.y="permalink")
# we have performed inner merge 

# # Alternate Approach for merge: we can make a unique column in the data sets unique by renaming
# # this will allow us to forego 'by.x' and 'by.y' command in the merge function.
# # code:
# #   colnames(final_companies)[1] <- "company_permalink"
# #   master_frame <- merge(final_rounds2, final_companies, by='company_permalink', all=F)


# we can confirm if the merge operation is successful, by finding out the no of unique
# permalinks in "master_frame" with our previous "companies_to_rounds_match" variable
# = 49516
length(unique(master_frame$company_permalink))
# 49516
nrow(master_frame)
# 85207


#=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=> 
#Checkpoint 2: Data Cleaning 2

# let us first check the no of NA values present in the raised_amount_usd column
length(master_frame[is.na(master_frame$raised_amount_usd),"raised_amount_usd"])
# 11238 no of records which have NA values

# now we have to analyse on how to treat them.
# let us first check what % of records in raised_amount_usd contains NA values
length(master_frame$raised_amount_usd[which(is.na(master_frame$raised_amount_usd))])/length(master_frame$raised_amount_usd)
# 13.18% of records in raised_amount_usd is NA

# since this analysis is being done for Spark Funds, it would be beneficial to replace
# NA values of raised_amount_usd based on the funding_type

# we will replace the NA values by Median (value under which 50% of obs lie), or Mean (Average of values)
# if the % of NA records is >10%


# now let us check individually, how we can replace NA values in raised_amount_usd, for
# the different funding_type are: angel, convertible_note, debt_financing, equity_crowdfunding,


# >>>>> analysis of NA in 'raised_amount_usd' for funding_type ="seed" <<<<<

nrow(master_frame[which(master_frame$funding_round_type=='seed' & is.na(master_frame$raised_amount_usd)),])
nrow(master_frame[which(master_frame$funding_round_type=='seed'),])
nrow(master_frame[which(master_frame$funding_round_type=='seed' & is.na(master_frame$raised_amount_usd)),])/nrow(master_frame[which(master_frame$funding_round_type=='seed'),])
# Total NA Records for Seed funding_round_type = 5565
# Total Records for Seed funding_round_type = 27133
# % of NA records = 20.51%
summary(master_frame[which(master_frame$funding_round_type=='seed'),"raised_amount_usd"])
#     Min.  1st Qu.   Median     Mean  3rd Qu.     Max.     NA's 
# 0.00e+00 6.00e+04 3.00e+05 7.38e+05 1.00e+06 2.00e+08     5565 
median_seed <- median(master_frame$raised_amount_usd[which(master_frame$funding_round_type=="seed" & !is.na(master_frame$raised_amount_usd))])
# calculate and assign median = 300,000
mean_seed <- mean(master_frame$raised_amount_usd[which(master_frame$funding_round_type=="seed" & !is.na(master_frame$raised_amount_usd))])
# calculate and assign mean = 737974.7

# 20.51% of the records of raised_amount_usd under seed funding type are NAs
# We have to handle NA values. This can be done be substituting the Mean or Median values
# we will go ahead and substitute the NAs with Median value, as there are quite a 
# number of values in raised_amount_usd which are extremely high, which are skewing the Mean value
master_frame[which(master_frame$funding_round_type=="seed" & is.na(master_frame$raised_amount_usd)),"raised_amount_usd"] <- median_seed



# >>>>> analysis of NA in 'raised_amount_usd' for funding_type ="angel" <<<<<

nrow(master_frame[which(master_frame$funding_round_type=='angel' & is.na(master_frame$raised_amount_usd)),])
nrow(master_frame[which(master_frame$funding_round_type=='angel'),])
nrow(master_frame[which(master_frame$funding_round_type=='angel' & is.na(master_frame$raised_amount_usd)),])/nrow(master_frame[which(master_frame$funding_round_type=='angel'),])
# Total NA Records for angel funding_round_type = 1025
# Total Records for angel funding_round_type = 5291
# % of NA records = 19.37%
summary(master_frame[which(master_frame$funding_round_type=='angel'),"raised_amount_usd"])
# Min.   1st Qu.    Median      Mean   3rd Qu.      Max.      NA's 
#   0    154200    400000    984000   1000000 494500000      1025 
median_angel <- median(master_frame$raised_amount_usd[which(master_frame$funding_round_type=="angel" & !is.na(master_frame$raised_amount_usd))])
# calculate and assign median = 400,000
mean_angel <- mean(master_frame$raised_amount_usd[which(master_frame$funding_round_type=="angel" & !is.na(master_frame$raised_amount_usd))])
# calculate and assign mean = 984013.7


# 19.37% of the records of raised_amount_usd under angel funding type are NAs
# We have to handle NA values. This can be done be substituting the Mean or Median values
# we will go ahead and substitute the NAs with Median value, as there are quite a 
# number of values in raised_amount_usd which are extremely high, which are skewing the Mean value
master_frame[which(master_frame$funding_round_type=="angel" & is.na(master_frame$raised_amount_usd)),"raised_amount_usd"] <- median_angel




# >>>>> analysis of NA in 'raised_amount_usd' for funding_type ="venture" <<<<<

nrow(master_frame[which(master_frame$funding_round_type=='venture' & is.na(master_frame$raised_amount_usd)),])
nrow(master_frame[which(master_frame$funding_round_type=='venture'),])
nrow(master_frame[which(master_frame$funding_round_type=='venture' & is.na(master_frame$raised_amount_usd)),])/nrow(master_frame[which(master_frame$funding_round_type=='venture'),])
# Total NA Records for venture funding_round_type = 4396
# Total Records for venture funding_round_type = 50752
# % of NA records = 8.66%
summary(master_frame[which(master_frame$funding_round_type=='venture'),"raised_amount_usd"])
#      Min.   1st Qu.    Median      Mean   3rd Qu.      Max.      NA's 
# 0.000e+00 1.627e+06 5.000e+06 1.189e+07 1.200e+07 1.760e+10      4396 
median_venture <- median(master_frame$raised_amount_usd[which(master_frame$funding_round_type=="venture" & !is.na(master_frame$raised_amount_usd))])
# calculate and assign median = 5,000,000
mean_venture <- mean(master_frame$raised_amount_usd[which(master_frame$funding_round_type=="venture" & !is.na(master_frame$raised_amount_usd))])
# calculate and assign mean = 11,888,940

# only 8.66% of records for raised_amount_usd under venture funding type are NAs
# we can ignore these values and proceed with our analysis
master_frame <- master_frame[which(!(master_frame$funding_round_type=='venture' & is.na(master_frame$raised_amount_usd))),]



# >>>>> analysis of NA in 'raised_amount_usd' for funding_type ="private_equity" <<<<<

nrow(master_frame[which(master_frame$funding_round_type=='private_equity' & is.na(master_frame$raised_amount_usd)),])
nrow(master_frame[which(master_frame$funding_round_type=='private_equity'),])
nrow(master_frame[which(master_frame$funding_round_type=='private_equity' & is.na(master_frame$raised_amount_usd)),])/nrow(master_frame[which(master_frame$funding_round_type=='private_equity'),])
# Total NA Records for private_equity funding_round_type = 251
# Total Records for private_equity funding_round_type = 2041
# % of NA records = 12.30%
summary(master_frame[which(master_frame$funding_round_type=='private_equity'),"raised_amount_usd"])
#       Min.   1st Qu.    Median      Mean   3rd Qu.      Max.      NA's 
# 0.000e+00 5.253e+06 2.000e+07 7.535e+07 7.576e+07 4.745e+09       251 
median_private_equity <- median(master_frame$raised_amount_usd[which(master_frame$funding_round_type=="private_equity" & !is.na(master_frame$raised_amount_usd))])
# calculate and assign median = 20,000,000
mean_private_equity <- mean(master_frame$raised_amount_usd[which(master_frame$funding_round_type=="private_equity" & !is.na(master_frame$raised_amount_usd))])
# calculate and assign mean = 75,354,440

# 12.30% of the records of raised_amount_usd under private_equity funding type are NAs
# We have to handle NA values. This can be done be substituting the Mean or Median values
# we will go ahead and substitute the NAs with Median value, as there are quite a 
# number of values in raised_amount_usd which are extremely high, which are skewing the Mean value
master_frame[which(master_frame$funding_round_type=="private_equity" & is.na(master_frame$raised_amount_usd)),"raised_amount_usd"] <- median_private_equity



# check if all the NA records of raised_amount_usd have been properly replaced
nrow(master_frame[which(is.na(master_frame$raised_amount_usd)),])
# 0
# we have successfully replaced all the NA values




#=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=> 
#Checkpoint 3: Funding Type Analysis

avg_seed_funding <- mean(master_frame[which(master_frame$funding_round_type=='seed'),"raised_amount_usd"])
# average funding for seed funding type = $ 648,145.7

avg_angel_funding <- mean(master_frame[which(master_frame$funding_round_type=='angel'),"raised_amount_usd"])
# average funding for angel funding type = $ 870,875.6

avg_venture_funding <- mean(master_frame[which(master_frame$funding_round_type=='venture'),"raised_amount_usd"])
# average funding for venture funding type = $ 11,888,940

avg_private_equity_funding <- mean(master_frame[which(master_frame$funding_round_type=='private_equity'),"raised_amount_usd"])
# average funding for private_equity funding type = $ 68,547,010


#Q1: Average funding amount of venture type: 
#Ans: $ 11,888,653

#Q2: Average funding amount of angel type:
#Ans: $ 870,875.6

#Q3: Average funding amount of seed type: 
#Ans: $ 648,153.8

#Q4: Average funding amount of private equity type: 
#Ans: $ 68,547,010

#Q5:  Considering that Spark Funds wants to invest between 5 to 15 million USD per
#investment round, which investment type is the most suitable for them?

#Ans: Most Suitable Investment Type is "Venture" Type for Spark Funds to invest in


#=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=> 
#Checkpoint 4: Country Analysis

# we have already shortlisted the "venture" as funding type based on constraints of Spark Funds
# all our further analyses will be done on funding type = venture
# let us create a seperate venture master from the master frame dataframe

venture_master <- master_frame[which(master_frame$funding_round_type=='venture'),]

# now we have to perform analysis on the total investment country wise.
# country details are available in country_code column.
# let us check if there are any NA values here, if so, how to go about treating them

nrow(venture_master[which(is.na(venture_master$country_code)),])/nrow(venture_master)
# No of NA records for country_code = 1607
# Total No. of records = 46355
# % of NA records = 3.46

# since the % of NA records is very low, we can easily ignore them
venture_master <- venture_master[which(!is.na(venture_master$country_code)),]

# spark Funds wants to see the top 9 countries which have received highest total funding

country_total_invest <- aggregate(venture_master$raised_amount_usd, by=list(venture_master$country_code), FUN=sum)
# perform rollup operation to get total investment done at country level

colnames(country_total_invest) <- c("country_code", "total_investment")
# renaming the column names of country wise total investment (aggregated dataframe)

country_total_invest <- country_total_invest[order(country_total_invest$total_investment, decreasing = T),]
# ordering the dataset in decreasing order of Total investments

rownames(country_total_invest) <- NULL
# changing the default rownames of country_total_invest DF

top9 <- country_total_invest[1:9,]
# creating a DF called top9 where details of top 9 countries 
# are available in the decreasing order of total investment

# Top English Speaking Country : USA
# Second English Speaking Country : GBR
# Third English Speaking Country : IND


#=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=> 
#Checkpoint 5: Sector Analysis 1

# >>>>>>>>>> Part 1: extracting the primary sector<<<<<<<<<<

# to extract primary sector from category list, we will use the "gsub" function.
# since the seperator '|' is by default treated as a symbol for  "OR" operation in R,
# this is treated as a Metacharachter in R, and we cannot directly perform gsub operation.
# as gsub expects a regular expression as a parameter.

# to do this, we append "\\" before "|" command so that R can convert the metacharachter to regular exp
venture_master$primary_sector <- gsub("\\|.*","",venture_master$category_list)

# Alternate Approach: 
# by using nested gsub functions, where we first convert the metacharachter (|) seperator 
# to regular expression seperator as below using fixed=T as a parameter within gsub function
# then replace all the values occuring after the regular expression by blanks

# actv_comp_w_catgry$primary_sector <- gsub(":.*", "", gsub("|", ":", actv_comp_w_catgry$category_list, fixed = T))

# let us check if all the rows of venture_master have their respective primary sector mentioned
nrow(venture_master[which(is.na(venture_master$primary_sector)),])
# 0


# >>>>>>>>>> Part 2: Map the primary_sector to main sector <<<<<<<<<<

# read the mapping file to a data frame
sector_mapping <- read.csv("mapping_file.csv", header = T, stringsAsFactors = F, na.strings = c(""," "))

sector_mapping[which(is.na(sector_mapping$category_list)),"main_sector"] <- "Others"
# assigning main sector of NA in category list as Others

ps_not_in_sec_map <- venture_master[!(venture_master$primary_sector %in% sector_mapping$category_list),]
nrow(ps_not_in_sec_map) # 9

# there are 9 records in venture master for which the primary sector mentioned is not available in 
# sector_mapping dataframe

# therefore we subset these 9 records and store to ps_not_in_sec_map and will 
# manually assign the main_sector to "Others"

nrow(venture_master) # 44748
# there is a match for all the primary_sector of venture_master in sector_mapping
# except 9
# we will assign the main_sector for these 9 records as "Others"
ps_not_in_sec_map$main_sector <- "Others"

# for all the other 44739 records, we will use merge operation (since this is the inner merge,
# the 9 values that do not have a match in sector mapping will not be considered in the merged frame)
venture_master <- merge(venture_master, sector_mapping, by.x="primary_sector", by.y="category_list")

# we now have 2 data frames, one where we were able to successfully merge the sector_mapping data
# other where we have manually changed the values to "Others"

# let us merge these 2 data sets to get the final dataset using rbind function
venture_master <- rbind(venture_master, ps_not_in_sec_map)

# now we have the main sector details for all the values in venture_master df



#=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=> 
#Checkpoint 6: Sector Analysis 2


count_agg_FT_funds_country <- aggregate(venture_master$raised_amount_usd[which(venture_master$country_code %in% c("USA", "GBR", "IND") & venture_master$raised_amount_usd>=5000000 & venture_master$raised_amount_usd<=15000000)],
                                        list(venture_master$country_code[which(venture_master$country_code %in% c("USA", "GBR", "IND") & venture_master$raised_amount_usd>=5000000 & venture_master$raised_amount_usd<=15000000)]), length)
sum_agg_FT_funds_country <- aggregate(venture_master$raised_amount_usd[which(venture_master$country_code %in% c("USA", "GBR", "IND") & venture_master$raised_amount_usd>=5000000 & venture_master$raised_amount_usd<=15000000)],
                                        list(venture_master$country_code[which(venture_master$country_code %in% c("USA", "GBR", "IND") & venture_master$raised_amount_usd>=5000000 & venture_master$raised_amount_usd<=15000000)]), sum)

# aggregated DF to calculate total sum and count of investments for "Venture" Funding Type,
# having investment amounts between 5-15 million USD, for the top 3 English Speaking Country
# viz. USA, GBR, IND


# Create three separate data frames D1, D2 and D3 for each of the 3 countries 
# containing the observations of funding type FT  falling between 5 to 15 million USD
# range. The three data frames should contain:

D1_USA <- venture_master[which(venture_master$country_code=="USA" & venture_master$raised_amount_usd>=5000000 & venture_master$raised_amount_usd <=15000000),]
D2_GBR <- venture_master[which(venture_master$country_code=="GBR" & venture_master$raised_amount_usd>=5000000 & venture_master$raised_amount_usd <=15000000),]
D3_IND <- venture_master[which(venture_master$country_code=="IND" & venture_master$raised_amount_usd>=5000000 & venture_master$raised_amount_usd <=15000000),]


nrow(D1_USA) #11287
nrow(D2_GBR) #582
nrow(D3_IND) #315

sum(D1_USA$raised_amount_usd)
sum(D2_GBR$raised_amount_usd)
sum(D3_IND$raised_amount_usd)
# creating seperate dataframes by subsetting venture_master for specific country code
# with investment amount between $5 million and $15 million


D1_count_invest <- aggregate(D1_USA$raised_amount_usd, list(D1_USA$main_sector), FUN=length)
D1_sum_invest <- aggregate(D1_USA$raised_amount_usd, list(D1_USA$main_sector), FUN=sum)

D2_count_invest <- aggregate(D2_GBR$raised_amount_usd, list(D2_GBR$main_sector), FUN=length)
D2_sum_invest <- aggregate(D2_GBR$raised_amount_usd, list(D2_GBR$main_sector), FUN=sum)

D3_count_invest <- aggregate(D3_IND$raised_amount_usd, list(D3_IND$main_sector), FUN=length)
D3_sum_invest <- aggregate(D3_IND$raised_amount_usd, list(D3_IND$main_sector), FUN=sum)
# rolling up based on main sector getting count and sum of investments

colnames(D1_count_invest) <- c("main_sector", "count_investment")
colnames(D2_count_invest) <- c("main_sector", "count_investment")
colnames(D3_count_invest) <- c("main_sector", "count_investment")
# renaming the columns of rolled up dataframes
colnames(D1_sum_invest) <- c("main_sector", "sum_investment")
colnames(D2_sum_invest) <- c("main_sector", "sum_investment")
colnames(D3_sum_invest) <- c("main_sector", "sum_investment")
#renaming the columns of rolled up dataframes

D1_USA <- merge(D1_USA, D1_count_invest, by="main_sector")
D1_USA <- merge(D1_USA, D1_sum_invest, by="main_sector")
# merging the count and sum of investment datasets with D1 dataset

D2_GBR <- merge(D2_GBR, D2_count_invest, by="main_sector")
D2_GBR <- merge(D2_GBR, D2_sum_invest, by="main_sector")
# merging the count and sum of investment datasets with D2 dataset

D3_IND <- merge(D3_IND, D3_count_invest, by="main_sector")
D3_IND <- merge(D3_IND, D3_sum_invest, by="main_sector")
# merging the count and sum of investment datasets with D3 dataset

D1_top_sectors <- D1_USA[D1_USA$main_sector %in% c("Others","Social, Finance, Analytics, Advertising","Cleantech / Semiconductors"),]
D2_top_sectors <- D2_GBR[D2_GBR$main_sector %in% c("Others","Social, Finance, Analytics, Advertising","Cleantech / Semiconductors"),]
D3_top_sectors <- D3_IND[D3_IND$main_sector %in% c("Others","Social, Finance, Analytics, Advertising","News, Search and Messaging"),]


D1_comp_sec_invest <- aggregate(D1_top_sectors$raised_amount_usd, by= list(D1_top_sectors$main_sector,D1_top_sectors$company_permalink, D1_top_sectors$name), FUN=sum)
D2_comp_sec_invest <- aggregate(D2_top_sectors$raised_amount_usd, by= list(D2_top_sectors$main_sector,D2_top_sectors$company_permalink, D2_top_sectors$name), FUN=sum)
D3_comp_sec_invest <- aggregate(D3_top_sectors$raised_amount_usd, by= list(D3_top_sectors$main_sector,D3_top_sectors$company_permalink, D3_top_sectors$name), FUN=sum)

#=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=>=> 
#Checkpoint 7: Plots

install.packages("ggplot2")
install.packages("scales")
library(ggplot2)
library(scales)

# > > > > > > > > > > Plot 1: < < < < < < < < < < 

# Create a Pie Chart showing the fraction of total investments (globally) in 
# venture, seed and #private equity and the average amount of investment in each funding type. 
# This chart should make it clear that a certain funding type (FT) is best suited for Spark Funds.

# for this let us first create a dataframe by aggregating based on funding type for 
# i) sum of investments
# ii) mean of investments


sum_agg_fund_invest <- aggregate(master_frame$raised_amount_usd[which(master_frame$funding_round_type!="angel")], list(master_frame$funding_round_type[which(master_frame$funding_round_type!="angel")]), FUN=sum)
colnames(sum_agg_fund_invest) <- c("funding_type", "sum_invest")
# aggregation of sum of investments

avg_agg_fund_invest <- aggregate(master_frame$raised_amount_usd[which(master_frame$funding_round_type!="angel")], list(master_frame$funding_round_type[which(master_frame$funding_round_type!="angel")]), FUN=mean)
colnames(avg_agg_fund_invest) <- c("funding_type", "avg_invest")
# mean of investments

agg_fund_invest <- merge(sum_agg_fund_invest, avg_agg_fund_invest, by="funding_type")
# merging sum & mean of investment into a single dataframe


# to plot a pie chart, we have to first plot a bar graph, and then use the coordinates function to convert the
# barplot into pie chart
bar_plot <- ggplot (agg_fund_invest, aes(x="", y=agg_fund_invest$sum_invest, fill=agg_fund_invest$funding_type)) + geom_bar(width = 1,stat = "identity")
pie_plot <- bar_plot + coord_polar(theta = "y", start = 1) + xlab("") + ylab("Sum of Investment") + ggtitle("Funding Type vs Total Investment") 

plot1 <- pie_plot + scale_fill_discrete(name = "Funding Type \n(Avg Funding)", 
                               breaks = c("private_equity", "seed", "venture"), 
                               labels = c('"Private Equity" \n($68.5 Million)', 
                                          '"Seed"\n($0.65 Million)', 
                                          '"Venture" \n($11.9 Million)'
                                          )
                               ) + theme(legend.key.height = unit(2,'lines'), legend.background = element_rect(colour = "black"))
# coord_polar ==> parameter theta="y" converts bar plot into pie
# scale_fill_discrete ==> to rename the legends and labels of legends
# theme ==> to manipulate spacing and position of the legend



# > > > > > > > > > > Plot 2: < < < < < < < < < <

# bar chart showing top 9 countries against the total amount of investments 
# of funding type FT. This should make the top 3 countries 
# (Country 1, Country 2 and Country 3) very clear.

bar_plot2 <- ggplot(top9, aes(x=reorder(top9$country_code, -top9$total_investment), y=top9$total_investment, fill = c(T, F, T, T, F, F, F, F, F))) 
plot2 <- bar_plot2 + geom_bar(stat = "identity") + xlab("Country") + ylab("Total Investment (USD)") +ggtitle("Country wise Total Investment\n(Venture Funding Type)") + scale_fill_discrete(guide=F)




# > > > > > > > > > > Plot 3: < < < < < < < < < <

# Any chart type you think is suitable: This should show the number of investments 
# in the top 3 sectors of the top 3 countries on one chart (for the chosen 
# investment type FT).

# let us use the 3 DF that we have previouslt created aggregating counts for individual country
# D1_count_invest, D2_count_invest and D3_count_invest
# let us add the country_code column to each of the above data frame
D1_count_invest$country_code <- "USA"
D2_count_invest$country_code <- "GBR"
D3_count_invest$country_code <- "IND"


# now that we have the 3 data frames, let us merge these values into a single dataframe
country_sector_count <- rbind(D1_count_invest,D2_count_invest,D3_count_invest)

country_sector_count$country_code <- factor(country_sector_count$country_code, levels = c("USA", "GBR", "IND"))
# set the factoring Order for facet wrapping.

bar_plot3 <- ggplot(country_sector_count, aes(x=reorder(main_sector, -count_investment), y=count_investment, fill=factor(main_sector))) + geom_bar(stat = "identity") + facet_wrap(~country_code, ncol=1, scales = "free_y")
intermediate <- bar_plot3 + xlab("Sectors") + ylab(" Total Count of Investments") + ggtitle("Number of Investments in various Sectors, Country wise")
intermediate2 <- intermediate + scale_fill_discrete(name = "Main Sector Details",
                                                    breaks = c("Automotive & Sports", "Cleantech / Semiconductors",
                                                               "Entertainment", "Health", "Manufacturing", 
                                                               "News, Search and Messaging", "Others", 
                                                               "Social, Finance, Analytics, Advertising"),
                                                    label = c("Automotive \n& Sports", "Cleantech \n/ Semiconductors",
                                                               "Entertainment", "Health", "Manufacturing", 
                                                               "News, Search \nand Messaging", "Others", 
                                                               "Social, Finance,\nAnalytics, Advertising")
                                                    ) + theme(legend.key.height = unit(2,'lines'))

plot3 <- intermediate2 + theme(axis.text.x = element_blank(), legend.background = element_rect(color = "black"))+ geom_text(label = country_sector_count$count_investment)
 