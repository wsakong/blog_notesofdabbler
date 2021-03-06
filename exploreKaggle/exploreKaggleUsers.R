##
## Explore Kaggle User data
##

# set working directory
setwd("~/notesofdabbler/githubfolder/blog_notesofdabbler/exploreKaggle/")

# load libraries
library(rvest)
library(stringr)
library(dplyr)
library(googleVis)
library(ggplot2)

# Get url of pages that contain users
# 13 pages correspond to about top 500 ranks

url = "http://www.kaggle.com/users"
urllist = paste(url,seq(2,13),sep="?page=")
urllist = c(url,urllist)
head(urllist)

# Function to parse user information from each page
getURL = function(url){
    # get list of users
    users = html(url) %>% html_nodes(".users-list")
    # get user names
    usrname = users %>% html_nodes(".profilelink") %>% html_text()
    # get user rank
    usrrnk = users %>% html_nodes(".rank") %>% html_text()
    # get number of competitions a user participated in 
    usrnumcomp = users %>% html_nodes(".comps") %>% html_text()
    # get user country 
    usrloc = users %>% html_nodes("li") %>% html_text()
    usrloc2 = sapply(as.list(usrloc),function(x) {
        xsplit = strsplit(x,"\r\n")[[1]]
        xtrim = str_trim(xsplit)
        xnoblank = xtrim[xtrim != ""]
        xloc = xnoblank[length(xnoblank)]
        return(xloc)
      })
    # combine into a dataframe
    usrdf = data.frame(usrname,usrrnk,usrnumcomp,usrloc2,stringsAsFactors = FALSE)
    return(usrdf)
}

# compile user information 
usrdf = list()
length(usrdf) = length(urllist)

for(i in 1:length(urllist)){
  usrdf[[i]] = getURL(urllist[i])
}

usrdf2 = rbind_all(usrdf)
head(usrdf2)

# clean up location field 
# currently logic of extracting location was looking for last entry in a vector
# if location is unknown, the last entry corresponds to number of competitions
# if location field has number of competitions, then it is set to unknown
tmpqc = usrdf2[grepl("competition",usrdf2[["usrloc2"]]),]
usrdf2[["usrloc2"]][grepl("competition",usrdf2[["usrloc2"]])] = "unknown"

# Convert user rank to a numeric value
usrdf2["usrrnk2"] = as.numeric(gsub("[^(0-9)]","",usrdf2[["usrrnk"]]))
# Convert number of competitions to a numeric value
usrdf2["usrnumcomp2"] = as.numeric(gsub("[^(0-9)]","",usrdf2[["usrnumcomp"]]))

# Get list of countries
cntrycnt = usrdf2 %>% group_by(usrloc2) %>% summarize(cntrycnt = n()) %>% arrange(desc(cntrycnt))
cntrylist = cntrycnt$usrloc2

# write country list to a csv file for manual cleaning
# Needed to manually assign country name that googleVis chart recognizes
#write.csv(cntrylist,"cntrylist.csv")

# read in the cleaned country list
cntrylist_cleaned = read.csv("cntrylist_cleaned.csv",sep=",")

# merge cleaned country list
usrdf3 = merge(usrdf2,cntrylist_cleaned,by.x=c("usrloc2"),by.y=c("cntryName"))
head(usrdf3)

# Summary by country
#  - number of users
#  - average rank of users
#  - best rank of users
#  - competitions per user
cntrycnt3 = usrdf3 %>% group_by(cntryName2)%>%
                  summarize(cntrycnt = n(),avgrnk = mean(usrrnk2),bestrnk = min(usrrnk2),
                            totcomp = sum(usrnumcomp2)) %>% 
                  arrange(bestrnk)
cntrycnt3["compperusr"] = cntrycnt3[["totcomp"]]/cntrycnt3[["cntrycnt"]]
head(cntrycnt3)

# plot user data (best rank by country) in a geochart
pltdf = cntrycnt3 %>% select(-totcomp)
names(pltdf) = c("country","NumberOfUsers","AverageRank","BestRank","CompetitionsPerUser")
G = gvisGeoChart(pltdf, locationvar = "country",
                        colorvar = "BestRank",
                        options=list(height=600,width=600))
T = gvisTable(pltdf,options = list(height=600,width=600),
              format=list(AverageRank = "#",
                          CompetitionsPerUser = "#.#"))

GT = gvisMerge(G,T,horizontal = TRUE)
plot(GT)

# Plot number of users by country
G2 = gvisGeoChart(pltdf, locationvar = "country",
                  colorvar = "NumberOfUsers",
                  options=list(height=600,width=600))
plot(G2)

