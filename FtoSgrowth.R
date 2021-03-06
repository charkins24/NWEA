## NWEA MAP Calculation of Fall to Spring Growth Results by Class and Grade, Displayed with Lighthouse Academies Metrics

## Load required R packages
library(dplyr)

print("NWEA MAP Fall to Spring Growth by Class and Grade")
print("This program requires as input the SPRING term AssessmentResults.csv, StudentsBySchool.csv, and processed ClassAssignments.csv files from the NWEA Comprehensive Data File Package, AND the FALL term AssessmentResults.csv file.") 
print("It also requires that the file 2015NWEANorms.csv be in the working directory.")
print("The program outputs tables with growth data for each class and grade level.")
print("Please see the readme file for important information on file name and pre-processing requirements")

## Read Spring Assessment Results file from CDF package into R
sscoresfilename <- readline(prompt="Enter name of file containing the SPRING scores. Include the .csv extension: ")
sscores <- read.csv(sscoresfilename)

## Read Student Demographics file from CDF package into R
sstudentsfilename <- readline(prompt="Enter name of file containing the SPRING student names and grade levels. Include the .csv extension: ")
sstudents <- read.csv(sstudentsfilename)

## Read Class Assignments file from CDF package into R
steachersfilename <- readline(prompt="Enter name of file containing the SPRING teacher names. Include the .csv extension: ")
steachers <- read.csv(steachersfilename)

## Read Fall Assessment Results file from CDF package into R
fscoresfilename <- readline(prompt="Enter name of file containing the FALL baseline scores. Include the .csv extension: ")
fscores <- read.csv(fscoresfilename)

## Read 2015 Norms into R
norms <- read.csv("2015NWEANorms.csv")

## Check if number of students in demographics file equals number in class assignments file and warn if it does not
if(nrow(sstudents)!=nrow(steachers)){warning("Number of students listed in demographics file does not equal number in class assignments file. Some students may be associated with more than one ELA or math teacher, or to no teacher and excluded from reports.")}

## Change grade K to 0 in student demographics file so that it is placed before grade 1 in sort order
sstudents$Grade <- gsub("K","0",sstudents$Grade)

## Merge spring student info with spring teacher names
## To work properly, the Class Assignments file should contain exactly one row for each student, with one ELA teacher and one math teacher listed.
## Any students without teachers in the Class Assignments file will be included with teachers listed as "NA"
## But any students whose IDs are not in the Student Demographics file will be excluded (should not normally happen)
steachers <- select(steachers, StudentID, ELATeacher, MathTeacher)
sstudentswithteachers <- merge(x=sstudents, y=steachers, by="StudentID", all.x=TRUE)

## Merge spring student info with spring scores, joining on student ID
## Include any records in the score table that are not in the student info table (should not usually happen)
## but do not include records in the student info table not in the score table (students not tested)
sscores <- select(sscores, -TermName, -SchoolName)
sdata <- merge(x=sstudentswithteachers, y=sscores, by="StudentID", all.y=TRUE)

## Remove from spring scores any test results that are not valid growth measures
## and any results for which there was no growth projection (usually due to lack of baseline score)
sdata <- sdata %>%
filter(GrowthMeasureYN==TRUE) %>%
filter(!is.na(FallToSpringProjectedGrowth))

## Remove from fall scores any test results that are not valid growth measures       
fscores <- filter(fscores, GrowthMeasureYN==TRUE)

## Select the variables needed and create separate, sorted tables for math and reading
smdata <- sdata %>% select(StudentID, StudentLastName, StudentFirstName, Grade, MathTeacher, TermName, SchoolName, MeasurementScale, SpringRIT=TestRITScore, SpringSE=TestStandardError, SpringPercentile=TestPercentile, FallToSpringProjectedGrowth, FallToSpringObservedGrowth) %>%
        filter(MeasurementScale == "Mathematics") %>%
        arrange(Grade, MathTeacher, StudentLastName, StudentFirstName)

srdata <- sdata %>% select(StudentID, StudentLastName, StudentFirstName, Grade, ELATeacher, TermName, SchoolName, MeasurementScale, SpringRIT=TestRITScore, SpringSE=TestStandardError, SpringPercentile=TestPercentile, FallToSpringProjectedGrowth, FallToSpringObservedGrowth) %>%
        filter(MeasurementScale == "Reading") %>%
        arrange(Grade, ELATeacher, StudentLastName, StudentFirstName)

fmscores <- fscores %>% select(StudentID, MeasurementScale, FallRIT=TestRITScore, FallSE=TestStandardError, FallPercentile=TestPercentile) %>%
        filter(MeasurementScale == "Mathematics")

frscores <- fscores %>% select(StudentID, MeasurementScale, FallRIT=TestRITScore, FallSE=TestStandardError, FallPercentile=TestPercentile) %>%
        filter(MeasurementScale == "Reading")

## Create new columns with quartile in spring data (derived from percentile)
smdata <- mutate(smdata, Quartile = ceiling((SpringPercentile/25)+.0001))
srdata <- mutate(srdata, Quartile = ceiling((SpringPercentile/25)+.0001))
smdata <- mutate(smdata, Q1=Quartile==1, Q2=Quartile==2, Q3=Quartile==3, Q4=Quartile==4)
srdata <- mutate(srdata, Q1=Quartile==1, Q2=Quartile==2, Q3=Quartile==3, Q4=Quartile==4)

## Merge fall scores into the spring data files, keeping only records for students who have both fall and spring scores
mgrowthscores <- merge(x=smdata, y=fmscores, by="StudentID")
rgrowthscores <- merge(x=srdata, y=frscores, by="StudentID")

## Create growth index columns
mgrowthscores <- mutate(mgrowthscores, GrowthIndex = FallToSpringObservedGrowth - FallToSpringProjectedGrowth)
mgrowthscores <- mutate(mgrowthscores, GrowthProjectionMet = GrowthIndex>=0)
rgrowthscores <- mutate(rgrowthscores, GrowthIndex = FallToSpringObservedGrowth - FallToSpringProjectedGrowth)
rgrowthscores <- mutate(rgrowthscores, GrowthProjectionMet = GrowthIndex>=0)

## Create growth error columns for calculating error bands
mgrowthscores <- mgrowthscores %>% mutate(GrowthSE = sqrt(FallSE*FallSE + SpringSE*SpringSE))
rgrowthscores <- rgrowthscores %>% mutate(GrowthSE = sqrt(FallSE*FallSE + SpringSE*SpringSE))

## Summarize the data by class, then add error bands and spring status norms
mgrowthbyclass <- mgrowthscores %>% 
        group_by(Grade, MathTeacher) %>%
        summarize(NumberInCohort = n(), 
                  FallMeanRIT = mean(FallRIT), 
                  SpringMeanRIT = mean(SpringRIT),
                  ActualMeanRITGrowth = mean(FallToSpringObservedGrowth), 
                  TypicalMeanRITGrowth = mean(FallToSpringProjectedGrowth),
                  PercentOfTypicalGrowthAchieved = mean(FallToSpringObservedGrowth) / mean(FallToSpringProjectedGrowth),
                  AvgGrowthSE = mean(GrowthSE),
                  NumberMeetingOrExceedingGrowthProjection = sum(GrowthProjectionMet), 
                  PercentMeetingOrExceedingGrowthProjection = sum(GrowthProjectionMet) / n(),
                  NumberinQuartile1 = sum(Q1), 
                  NumberinQuartile2 = sum(Q2), 
                  NumberinQuartile3 = sum(Q3), 
                  NumberinQuartile4 = sum(Q4)) %>%
        mutate(PercentInHighestQuartile = NumberinQuartile4 / NumberInCohort) %>%
        mutate(CohortGrowthME = (AvgGrowthSE/sqrt(NumberInCohort))*2) %>%
        mutate(PercentofTypicalGrowthLowerBound = (ActualMeanRITGrowth - CohortGrowthME) / TypicalMeanRITGrowth) %>%
        mutate(PercentofTypicalGrowthUpperBound = (ActualMeanRITGrowth + CohortGrowthME) / TypicalMeanRITGrowth)
smnorms <- select(norms, Grade, NationalNormSpringMeanMathRIT) 
mgrowthbyclass <- merge(x=mgrowthbyclass, y=smnorms)
mgrowthbyclass <- mgrowthbyclass %>%
        mutate(NationalNormSpringMeanExceededOrMissedBy = SpringMeanRIT - NationalNormSpringMeanMathRIT)
mgrowthbyclass <- mgrowthbyclass[,c(2,1,3,4,5,20,21,6,7,8,18,19,10,11,12,13,14,15,16)]
        
rgrowthbyclass <- rgrowthscores %>% 
        group_by(Grade, ELATeacher) %>%
        summarize(NumberInCohort = n(), 
                  FallMeanRIT = mean(FallRIT), 
                  SpringMeanRIT = mean(SpringRIT),
                  ActualMeanRITGrowth = mean(FallToSpringObservedGrowth), 
                  TypicalMeanRITGrowth = mean(FallToSpringProjectedGrowth),
                  PercentOfTypicalGrowthAchieved = mean(FallToSpringObservedGrowth) / mean(FallToSpringProjectedGrowth),
                  AvgGrowthSE = mean(GrowthSE),
                  NumberMeetingOrExceedingGrowthProjection = sum(GrowthProjectionMet), 
                  PercentMeetingOrExceedingGrowthProjection = sum(GrowthProjectionMet) / n(),
                  NumberinQuartile1 = sum(Q1), 
                  NumberinQuartile2 = sum(Q2), 
                  NumberinQuartile3 = sum(Q3), 
                  NumberinQuartile4 = sum(Q4)) %>%
        mutate(PercentInHighestQuartile = NumberinQuartile4 / NumberInCohort) %>%
        mutate(CohortGrowthME = (AvgGrowthSE/sqrt(NumberInCohort))*2) %>%
        mutate(PercentofTypicalGrowthLowerBound = (ActualMeanRITGrowth - CohortGrowthME) / TypicalMeanRITGrowth) %>%
        mutate(PercentofTypicalGrowthUpperBound = (ActualMeanRITGrowth + CohortGrowthME) / TypicalMeanRITGrowth)
srnorms <- select(norms, Grade, NationalNormSpringMeanReadingRIT) 
rgrowthbyclass <- merge(x=rgrowthbyclass, y=srnorms)
rgrowthbyclass <- rgrowthbyclass %>%
        mutate(NationalNormSpringMeanExceededOrMissedBy = SpringMeanRIT - NationalNormSpringMeanReadingRIT)
rgrowthbyclass <- rgrowthbyclass[,c(2,1,3,4,5,20,21,6,7,8,18,19,10,11,12,13,14,15,16)] 

## Summarize data by grade
mgrowthbygrade <- mgrowthscores %>% 
        group_by(Grade) %>%
        summarize(NumberInCohort = n(), 
                  FallMeanRIT = mean(FallRIT), 
                  SpringMeanRIT = mean(SpringRIT),
                  ActualMeanRITGrowth = mean(FallToSpringObservedGrowth), 
                  TypicalMeanRITGrowth = mean(FallToSpringProjectedGrowth),
                  PercentOfTypicalGrowthAchieved = mean(FallToSpringObservedGrowth) / mean(FallToSpringProjectedGrowth),
                  AvgGrowthSE = mean(GrowthSE),
                  NumberMeetingOrExceedingGrowthProjection = sum(GrowthProjectionMet), 
                  PercentMeetingOrExceedingGrowthProjection = sum(GrowthProjectionMet) / n(),
                  NumberinQuartile1 = sum(Q1), 
                  NumberinQuartile2 = sum(Q2), 
                  NumberinQuartile3 = sum(Q3), 
                  NumberinQuartile4 = sum(Q4)) %>%
        mutate(PercentInHighestQuartile = NumberinQuartile4 / NumberInCohort) %>%
        mutate(CohortGrowthME = (AvgGrowthSE/sqrt(NumberInCohort))*2) %>%
        mutate(PercentofTypicalGrowthLowerBound = (ActualMeanRITGrowth - CohortGrowthME) / TypicalMeanRITGrowth) %>%
        mutate(PercentofTypicalGrowthUpperBound = (ActualMeanRITGrowth + CohortGrowthME) / TypicalMeanRITGrowth)
smnorms <- select(norms, Grade, NationalNormSpringMeanMathRIT) 
mgrowthbygrade <- merge(x=mgrowthbygrade, y=smnorms)
mgrowthbygrade <- mgrowthbygrade %>%
        mutate(NationalNormSpringMeanExceededOrMissedBy = SpringMeanRIT - NationalNormSpringMeanMathRIT)
mgrowthbygrade <- mgrowthbygrade[,c(1,2,3,4,19,20,5,6,7,17,18,9,10,11,12,13,14,15)]

rgrowthbygrade <- rgrowthscores %>% 
        group_by(Grade) %>%
        summarize(NumberInCohort = n(), 
                  FallMeanRIT = mean(FallRIT), 
                  SpringMeanRIT = mean(SpringRIT),
                  ActualMeanRITGrowth = mean(FallToSpringObservedGrowth), 
                  TypicalMeanRITGrowth = mean(FallToSpringProjectedGrowth),
                  PercentOfTypicalGrowthAchieved = mean(FallToSpringObservedGrowth) / mean(FallToSpringProjectedGrowth),
                  AvgGrowthSE = mean(GrowthSE),
                  NumberMeetingOrExceedingGrowthProjection = sum(GrowthProjectionMet), 
                  PercentMeetingOrExceedingGrowthProjection = sum(GrowthProjectionMet) / n(),
                  NumberinQuartile1 = sum(Q1), 
                  NumberinQuartile2 = sum(Q2), 
                  NumberinQuartile3 = sum(Q3), 
                  NumberinQuartile4 = sum(Q4)) %>%
        mutate(PercentInHighestQuartile = NumberinQuartile4 / NumberInCohort) %>%
        mutate(CohortGrowthME = (AvgGrowthSE/sqrt(NumberInCohort))*2) %>%
        mutate(PercentofTypicalGrowthLowerBound = (ActualMeanRITGrowth - CohortGrowthME) / TypicalMeanRITGrowth) %>%
        mutate(PercentofTypicalGrowthUpperBound = (ActualMeanRITGrowth + CohortGrowthME) / TypicalMeanRITGrowth)
srnorms <- select(norms, Grade, NationalNormSpringMeanReadingRIT) 
rgrowthbygrade <- merge(x=rgrowthbygrade, y=srnorms)
rgrowthbygrade <- rgrowthbygrade %>%
        mutate(NationalNormSpringMeanExceededOrMissedBy = SpringMeanRIT - NationalNormSpringMeanReadingRIT)
rgrowthbygrade <- rgrowthbygrade[,c(1,2,3,4,19,20,5,6,7,17,18,9,10,11,12,13,14,15)] 

## Save tables to files and print completion message
write.csv(mgrowthbyclass, file="FallToSpringMathGrowthByClass.csv", row.names=FALSE)
write.csv(rgrowthbyclass, file="FallToSpringReadingGrowthByClass.csv", row.names=FALSE)
write.csv(mgrowthbygrade, file="FallToSpringMathGrowthByGrade.csv", row.names=FALSE)
write.csv(rgrowthbygrade, file="FallToSpringReadingGrowthByGrade.csv", row.names=FALSE)
print("Processing complete!")
print("Output files have been saved in working directory.")
print("Move or rename output files before running this script again, or else files will be overwritten.")