# SparksFund_investProject Brief:

Project Brief:

  You are working for Spark Funds, an asset management company. Spark Funds wants to make investments in a few companies. The CEO of Spark Funds wants to understand the global trends in investments so that she can take the investment decisions effectively.
  
Business and Data Understanding: 

Spark Funds have two minor constraints for investments:
1))They want to invest between 5 to 15 million USD per round of investment.
2)They want to invest only in English-speaking countries because of the ease of communication with the companies they’d invest in.
 
1. What is the Strategy?
  Spark Funds wants to invest where most other investors are investing. This pattern is often observed among early stage start-up investors.
 
2. Where did we get the data from? 
  We have taken real investment data from crunchbase.com, so the insights you get may be incredibly useful. For this group project, we have divided the data into the following files:
  
You have to use 3 data files for the entire analysis:
1. companies.txt: A text file with basic data of companies.

 Attributes description of companies.txt file
 Attributes:-Description
 Permalink:-Unique ID of company
 Name:-Company name
 Homepage_url:-Website URL
 Category_list:-Category/categories to which a company belongs
 Status:-Operational status
 Country_code:-Country
 State_code:-State
 
2. rounds2.csv: A csv file with data about investments. The most important parameters are explained below:

 Attribute description of rounds2.csv file
 Attributes			Description
 company_permalink 		Unique ID of company
 funding_round_permalink	Unique ID of funding round
 funding_round_type		Type of funding – venture, angel, private equity  etc.
 funding_round_code		Round of venture funding (round A, B etc.)
 funded_at			Date of funding
 raised_amount_usd		Money raised in funding (USD)
 
3. mapping_file.csv: This file maps the numerous sector names (like 3D printing, aerospace, agriculture etc.) to 8 main sector names. The purpose of having 8 main sectors is to simplify the analysis into 8 sector buckets, rather than trying to analyse hundreds of them.
 
3. What is Spark Funds’ business objective?
The business objectives and goals of data analysis are pretty straightforward.

Business objective: The objective is to identify the best sectors, countries and a suitable investment type for making investments. The overall strategy is to invest where others are investing, implying that the best sectors and countries are the ones where most investments are happening.

Goals of data analysis: Your goals are divided into 3 main sub-goals:
Investment type analysis: Understanding investments in venture, seed/angel, private equity categories etc. so Spark Funds can decide which type is best suited for their strategy.

Country analysis: Understanding which countries have had the most investments in the past. These will be Spark Funds’ favourites as well.

Sector analysis: Understanding the distribution of investments across the 8 main sectors (note that we are interested in the 8 main sectors provided in the mapping file. The 2 files, companies and rounds2, have numerous sub-sector names; hence you will need to map each sub-sector to its main sector)

