#   Filename: HGsynergyMain_merge2.R 
#   Purpose: Concerns radiogenic mouse HG tumorigenesis.

#   Copyright: (C) 2017 Mark Ebert, Edward Huang, Dae Woong Ham, Yimin Lin, and Ray Sachs

#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License version 3 as published 
#   by the Free Software Foundation.

#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.

#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

#   Attribution Information: This R script was developed at UC Berkeley.
#   < authors and contributions to be added later > 

#   Relevant references and abbreviations:
#   ".93Alp" = Alpen et al. "Tumorigenic potential of high-Z, high-LET charged-particle radiations." Rad Res 136:382-391 (1993)
#   ".94Alp" = Alpen et al. "Fluence-based relative biological effectiveness for charged particle carcinogenesis in mouse Harderian gland." Adv Space Res 14(10): 573-581. (1994).  
#   "16Chang" = Chang et al. "Harderian Gland Tumorigenesis: Low-Dose and LET Response." Radiat Res 185(5): 449-460. (2016).  
#   "16Srn" = Siranart et al."Mixed Beam Murine Harderian Gland Tumorigenesis: Predicted Dose-Effect Relationships if neither Synergism nor Antagonism Occurs." Radiat Res 186(6): 577-591 (2016).  
#   "17Cuc" = Cucinotta & Cacao. "Non-Targeted Effects Models Predict Significantly Higher Mars Mission Cancer Risk than Targeted Effects Models." Sci Rep 7(1): 1832. (2017). PMC5431989

library(deSolve) #  solving differential equations
library(ggplot2) #  plotting
library(mvtnorm) #  Monte Carlo simulation
library(minpack.lm) #  non-linear regression 
rm(list=ls())
#=========================== DATA START ===========================#
dfr <- data.frame( #  data used in 16Chang; includes data analyzed in .93Alp and .94Alp  
  dose.1 = c(0.2,0.4,0.6,1.2,2.4,3.2,5.1,7,0.05,0.1,0.15,0.2,0.4,0.8,1.6,0.05,0.1,0.2,0.4,0,0.1,0.2,0.4,0.8,1.6,0.4,0.8,1.6,3.2,0.05,0.1,0.2,0.4,0.8,0.1,0.2,0.4,0.8,0.1,0.2,0.4,0.04,0.08,0.16,0.32,0.033,0.066,0.13,0.26,0.52,.2, .4, .6),
  HG = c(0.091,0.045,0.101,0.169,0.347,0.431,0.667,0.623,0.156,0.215,0.232,0.307,0.325,0.554,0.649,0.123,0.145,0.207,0.31,0.026,0.083,0.25,0.39,0.438,0.424,0.093,0.195,0.302,0.292,0.109,0.054,0.066,0.128,0.286,0.183,0.167,0.396,0.536,0.192,0.234,0.317,0.092,0.131,0.124,0.297,0.082,0.088,0.146,0.236,0.371,.154,.132,.333), #  HG prevalence as defined in 16Chang
  NWeight = c(520,2048,1145,584,313,232,293,221,1162,877,455,409,374,223,320,742,661,347,131,6081,1091,251,244,191,131,645,255,199,111,649,378,973,833,201,468,381,197,109,496,257,185,1902,1063,884,350,1767,1408,874,299,261,322,206,67), #  nominal weight for weighted least squaresregression; see .93Alp. The Lanthanum entries were obtained by measuring the main graph in 17Cuc 
  index=c(rep(1,8),rep(0,17), rep(1,4),  rep(0,24)), #  index=0 for Z>3 ions, 1 otherwise. Not needed in some models
  L = c(rep(1.6,8), rep(193, 7), rep(250, 4), rep(195, 6), rep(0.4, 4), rep(25, 5), rep(464, 4), rep(193, 3),rep(70, 4), rep(100, 5), rep(953, 3)), #  L = LET = LET_infinity = stopping power (keV/micron)
  Z = c(rep(2, 8), rep(26, 17), rep(1, 4), rep(10, 5), rep(43, 4), rep(26, 3), rep(14, 4), rep(22, 5), rep(57, 3)), #  atomic number, charge in units of proton charge on fully ionized atomic nucleus, e.g. 2 for 2He4
  Zeff = c(rep("TBD", 53)), #  effective ion charge according to the formula of W.H Barkas. Zeff <= Z. Calculated below. For this data, only very slightly less than Z.
  beta = c(rep("TBD", 53)), #  ion speed, relative to speed of light, calculated below
  MeVperu = c(rep(228, 8), rep(600, 7), rep(300, 4), rep(600, 6), rep(250, 4), rep(670, 5), rep(600, 4), rep(600, 3), rep(260, 4), rep(1000, 5), rep(593, 3)), #  Kinetic energy in MeV, divided by atomic mass, e.g. divided by 4u=4x931.5 MeV/c^2 for 2He4
  Katz = c(rep("TBD", 53)), #  for fully ionized nuclei, Katz's Z^2/beta^2, Calculated below. It is part of the Bethe Barkas Bloch equation for stopping power. Our calculations don't use Katz, but various similar calculations do.
  ion = c(rep("He4", 8), rep("Fe56", 17), rep("p", 4), rep("Ne20", 5), rep("Nb93", 4), rep("Fe56", 3), rep("Si28", 4), rep("Ti48", 5), rep("La139", 3)),
  comments = c(".93AlpLooksOK", rep("", 7), ".93AlplooksOK", rep("", 11), ".93Alp.no.iso", "not in 17Cuc (or 16Chang?)", rep("", 3), "16Chang all OK?", rep('', 24), ".94Alp","From graphs",'e.g. in 17Cuc')
) 

# Data for HG induced by photons from Cs-137 or Co-60 beta decay; from 16Chang (and calibration of LQ model)
ddd <- data.frame(dose.1 = c(0, 0.4, 0.8, 1.6, 3.2, 7, 0, .4, .8, .12, 1.6),
                  HG = c(.026, .048, .093, .137, .322, .462, .0497, .054, .067, .128, .202),
                  NWeight = c(6081.2, 4989.5, 1896.8, 981.1, 522.2, 205.2, 7474.1, 2877.6, 1423.7, 689.9, 514.9),
                  Nucleus = c(rep("Cobalt-60", 6), rep("Cesium-137", 5)),
                  Comments = c(rep("TBD", 11))
)
GeVu <- 0.001 * dfr[, "MeVperu"] #  convert to GeV/u for convenience in a calculation
dfr[, "Katz"] <- round(dfr[, "Z"] ^2 * (2.57 * GeVu ^2 + 4.781 * GeVu + 2.233) / (2.57 * GeVu ^2 + 4.781 * GeVu), 2) #  special relativistic calculation of Z^2/beta^2. The numerics include conversion from GeV to joules and from u to kg.
dfr[, "beta"] <- round(dfr[, "Z"] * sqrt(1 / dfr[, "Katz"]), 3) #  i.e. Z*sqrt(beta^2/Z^2) 
dfr[, "Zeff"] <- round(dfr[, "Z"] * (1 - exp( -125 * dfr[, "Z"] ^ (-2.0 / 3))), 2) #  Barkas formula for Zeff; for us Zeff is almost Z

dfra <- dfr[c(1:19, 26:53), ] #  removes the zero dose case and the no isograft data
#=========================== DATA END ===========================#

#####  photon model #####
LQ <- lm(HG ~ dose.1 + I(dose.1 ^ 2), data = ddd) # linear model fit on ddd dataset
summary(LQ, correlation = T) 

#===================== HZE/NTE MODEL, abbreviated  "hin" for "high non-targeted" =====================# 
# Uses 3 adjustable parameters. There is also an HZE/TE model, abbreviated "hit" for "high targeted" and a "LOW"
# model for Z <= 3. Both hin and hit are for Z>3 in principle and here have data for Z >= 8.  

dfrHZE <- subset(dfra, Z > 3) # look only at HZE not at much lower Z and LET ions. # In next line phi controls how fast NTE build up from zero; not really needed during calibration since phi*Dose>>1 at every observed Dose !=0. phi needed for later synergy calculations.

phi <- 2000#  even larger phi should give the same final results, but might cause extra problems with R. 
hinm <- nls(HG ~ .0275 + (1 - exp ( -0.01 * (aa1 * L * dose.1 * exp( -aa2 * L) + (1 - exp( - phi * dose.1)) * kk1))), #  calibrating parameters in a model that modifies the hazard function NTE models in 17Cuc. "hinm" is for hin model
            data = dfrHZE, 
            weights = NWeight,
            start = list(aa1 = .9, aa2 = .01, kk1 = 6)) 
summary(hinm, correlation = T); vcov(hinm) #  parameter values & accuracy; variance-covariance matrix RKSB
hin.c <- coef(hinm) #  calibrated central values of the 3 parameters. Next is the IDER, = 0 at dose 0
hanC <- function(dose.1,L) { #  calibrated hazard function "hanC" is for hazard non-targeted calibrated
  0.01 * (hin.c[1] * L * dose.1 * exp(-hin.c[2] * L) + (1 - exp(- phi * dose.1)) * hin.c[3])
} 
Calculate.hinC <- function(dose.1, L) {
  1 - exp(-hanC(dose.1, L)) #  Calibrated HZE NTE IDER
}
######### TE model #########
hitm <- nls(HG ~ .0275 + (1 - exp ( -0.01 * (aate1 * L * dose.1 * exp( -aate2 * L) ))), #  calibrating parameters in a TE only model.
            data = dfrHZE,  
            weights = NWeight,
            start = list(aate1 = .9, aate2 = .01)) 
summary(hitm, correlation = T); vcov(hitm) #  parameter values & accuracy; variance-covariance matrix RKSB
hit.c <- coef(hitm) #  calibrated central values of the 2 parameters. Next is the IDER, = 0 at dose 0
hatC <- function(dose.1,L) { #  calibrated hazard function
  0.01 * (hit.c[1] * L * dose.1 * exp(-hit.c[2] * L))
} 
Calculate.hitC <- function(dose.1, L) {
  1 - exp(-hatC(dose.1, L)) #  Calibrated HZE TE IDER
}
IC<-cbind(AIC(hitm,hinm),BIC(hitm,hinm))
print(IC)
dose <- c(seq(0, .00001, by = 0.000001), #  look carefully near zero, but go out to 0.5 Gy
          seq(.00002, .0001, by=.00001),
          seq(.0002, .001, by=.0001),
          seq(.002, .01, by=.001),
          seq(.02, .5, by=.01))
# dose <- dose[1:30] #  this can be used to zoom in on the very low dose behavior in the graphs

####### calculate baseline MIXDER I(d) for mixtures of HZE components modeled by NTE IDER and then those by TE IDER #######
IntegratehinMIXDER <- function(r, L, d = dose, aa1 = hin.c[1], aa2 = hin.c[2], kk1 = hin.c[3]) {
  dE <- function(yini, State, Pars) {
    aa1 <- aa1; aa2 <- aa2; kk1 <- kk1
    with(as.list(c(State, Pars)), {
      aa = vector(length = length(L))
      u = vector(length = length(L))
      for (i in 1:length(L)) {
        aa[i] = aa1*L[i]*exp(-aa2*L[i])
        u[i] = uniroot(function(d) 1-exp(-0.01*(aa[i]*d+(1-exp(-phi*d))*kk1)) - I, lower = 0, upper = 20, tol = 10^-10)$root
      }
      dI = vector(length = length(L))
      for (i in 1:length(L)) {
        dI[i] = r[i]*0.01*(aa[i]+exp(-phi*u[i])*kk1*phi)*exp(-0.01*(aa[i]*u[i]+(1-exp(-phi*u[i]))*kk1))
        
      }
      dI = sum(dI)
      return(list(c(dI)))
    })
  }
  pars = NULL; yini = c(I= 0); d = d
  out = ode(yini, times = d, dE, pars, method = "radau")
  return(out)
} 
#Now hit instead of hin
Integrate_hiteMIXDER <- function(r, L, d = dose, aate1 = hit.c[1], aate2 = hit.c[2]) {
  dE <- function(yini, State, Pars) {
    aate1 <- aate1; aate2 <- aate2; kk1 <- kk1
    with(as.list(c(State, Pars)), {
      aate = vector(length = length(L))
      u = vector(length = length(L))
      for (i in 1:length(L)) {
        aate[i] = aate1*L[i]*exp(-aate2*L[i])
        u[i] = uniroot(function(d) 1-exp(-0.01*(aate[i]*d)) - I, lower = 0, upper = 20, tol = 10^-10)$root
      }
      dI = vector(length = length(L))
      for (i in 1:length(L)) {
        dI[i] = r[i]*0.01*aate[i]*exp(-0.01*(aate[i]*u[i]))
        
      }
      dI = sum(dI)
      return(list(c(dI)))
    })
  }
  pars = NULL; yini = c(I= 0); d = d
  out = ode(yini, times = d, dE, pars, method = "radau")
  return(out)
} 
########### Light ion, low Z (<= 3), low LET model ######### 
dfrL <- subset(dfra, Z <= 3) #  for Light ions
LOW.m <- nls(HG ~ .0275 + 1-exp(-bet * dose.1),
             data = dfrL,
             weights = NWeight,
             start = list(bet = .5))
summary(LOW.m)
LOW.c <- coef(LOW.m)  # calibrated central values of the parameter
CalculateLOW.C <- function(dose.1, L) { # Calibrated Low LET model. Use L=0, but maybe later will use L >0 but small 
  return(1 - exp(-LOW.c[1] * dose.1))
}  

dE_2 <- function(dose,L) { # Slope dE/dd of the low LET, low Z model; looking at the next plot() it seems fine
  LOW.c*exp(-LOW.c*dose)  
}

# plot () chunks such as the following are visual check to see if our calibration is consistent with 16Chang, .93Alp, .94Alp
# and 17Cuc; (ggplot commands are Yinmin's and concern CI)
# Put various values in our calibrated model to check with numbers and graphs in these references
plot(c(0, 7), c(0, 1), col = 'red', ann = 'F') 
ddose <- 0.01 * 0:700; lines(ddose, CalculateLOW.C(ddose, 0) + .0275)  #  calibrated lowLET IDER
points(dfrL[1:8, "dose.1"], dfrL[1:8,"HG"],pch=19) #  RKS: Helium data points
points(dfrL[9:12, "dose.1"], dfrL[9:12, "HG"] )  #  proton data points 

####### remove following lines I think RKS ####### 
#dE_1 <- function(d, aa1, aa2, kk1, phi, L) { # For hin
#    ((kk1 * phi * exp(-phi * d )  + aa1 * L * exp( -aa2 * L)) * 
#   exp(-0.01 * (kk1 * (1 - exp( -phi * d)) + aa1 * L * exp(-aa2 * L) * d))) / 100
#  }
########## END remove these lines RKS #########

################## I(d) calculator for high Z, high E, NTE model hinm plus optionally LOW. START ##################
calculateComplexId <- function(r, L, d, aa1 = hin.c[1], aa2 = hin.c[2], kk1 = hin.c[3], phi = 2000, beta = LOW.c, lowLET = FALSE) {
  # Calculates incremental effect additivity function I(d) for mixture of N >= 1 HZE NTE IDERs and optionally one low-LET IDER 
  # new argument: lowLET (FALSE by default, TRUE when one IDER is low-LET)
  dE <- function(yini, State, Pars) { #  Constructing an ode from the IDERS
    aa1 <- aa1; aa2 <- aa2; kk1 <- kk1; beta <- beta; phi <- phi; L <- L
    with(as.list(c(State, Pars)), {
      aa <- vector(length = length(L))  
      u <- vector(length = length(L))  
      for (i in 1:length(L)) {
        aa[i] <- aa1 * L[i] * exp(-aa2 * L[i])
        u[i] <- uniroot(function(d) 1-exp(-0.01*(aa1*L[i]*d*exp(-aa2*L[i])+(1-exp(-phi*d))*kk1)) - I, lower = 0, upper = 200, extendInt = "yes", tol = 10^-10)$root #egh this is used in the single HZE and lowLET example
      }
      dI <- vector(length = length(L))
      for (i in 1:length(L)) {
        dI[i] <- r[i] * 0.01*(aa[i]+exp(-phi*u[i])*kk1*phi)*exp(-0.01*(aa[i]*u[i]+(1-exp(-phi*u[i]))*kk1))
      }
      if (lowLET == TRUE) { # If low-LET IDER is present then include it at the end of the dI vector
        u[length(L) + 1] <- uniroot(function(d) 1-exp(-beta*d) - I, lower = 0, upper = 200, extendInt = "yes", tol = 10^-10)$root
        dI[length(L) + 1] <- r[length(r)] * dE_2(d = u[length(L) + 1], L = 0)
      }
      dI <- sum(dI)
      return(list(c(dI)))
    })
  }
  return(ode(c(I = 0), times = d, dE, parms = NULL, method = "radau")) #  Finds solution I(d) of the differential equation
  # RKS to Yimin and Edward: I'm not convinced we need to or should add that the method is radau
}
################## I(d) calculator for high Z, high E, NTE model hinm plus optionally LOW. END ##################

###### RKS to Yimin and Edward: Next is the same for hitm; then some plots #####
calculateComplexId.te <- function(r, L, d, aate1 = hit.c[1], aate2 = hit.c[2], beta = LOW.c, lowLET = FALSE) {
  dE <- function(yini, State, Pars) { #  Constructing an ode from the IDERS
    aate1 <- aate1; aate2 <- aate2; beta <- beta; L <- L
    with(as.list(c(State, Pars)), {
      aate <- vector(length = length(L))
      u <- vector(length = length(L))
      for (i in 1:length(L)) {
        aate[i] <- aate1 * L[i] * exp(-aate2 * L[i])
        u[i] <- uniroot(function(d) 1-exp(-0.01*(aate1*L[i]*d*exp(-aate2*L[i]))) - I, lower = 0, upper = 200, extendInt = "yes", tol = 10^-10)$root
      }
      dI <- vector(length = length(L))
      for (i in 1:length(L)) {
        dI[i] <- r[i] * 0.01*aate[i]*exp(-0.01*aate[i]*u[i])
      }
      if (lowLET == TRUE) { # If low-LET IDER is present then include it at the end of the dI vector
        u[length(L) + 1] <- uniroot(function(d) 1-exp(-beta*d) - I, lower = 0, upper = 200, extendInt = "yes", tol = 10^-10)$root
        dI[length(L) + 1] <- r[length(r)] * dE_2(d = u[length(L) + 1], L = 0)
      }
      dI <- sum(dI)
      return(list(c(dI)))
    })
  }
  return(ode(c(I = 0), times = d, dE, parms = NULL, method = "radau")) #  Finds solution I(d) of the differential equation
}
# RKS to Yimin and Edward: I'm not convinced we need to or should add that the method is radau


# Example Plot 1 : one HZE one low-LET for hin
# d <- .01 * 0:300.; r1 <- .2; r <- c(r1, 1 - r1) #Proportions. Next plot IDERs and MIXDER
# plot(x = d, y = Calculate.hinC(dose.1 = d, L = 173), type = "l", xlab="dose",ylab="HG",bty='l',col='green',lwd=2)
# lines(x = d, y = CalculateLOW.C( d,0), col='green', lwd=2)
#lines(x = d, y = calculateComplexId(r = r, L = 193, d = d, lowLET = TRUE)[, 2], col = "red", lwd=2) # I(d)
# 
# # Example Plot 1hit : one HZE one low-LET for hit
# d <- .01 * 0:300.; r1 <- .2; r <- c(r1, 1 - r1) #Proportions. Next plot IDERs and MIXDER
# plot(x = d, y = Calculate.hitC(dose.1 = d, L = 173), type = "l", xlab="dose",ylab="HG",bty='l',col='green',lwd=2)
# lines(x = d, y = CalculateLOW.C( d,0), col='green', lwd=2)
# lines(x = d, y = calculateComplexId.te(r = r, L = 193, d = d, lowLET = TRUE)[, 2], col = "red", lwd=2) # I(d)
# 
# # Example Plot 2: four HZE
# r <- rep(0.25,4); L <- c(25, 70, 190, 250)
# plot(calculateComplexId(r, L, d = dose), type='l', col='red', bty='l', ann='F') #  I(d) plot
# SEA <- function(dose.1) Calculate.hinC(dose.1/4, 25) + Calculate.hinC(dose.1/4, 70) + Calculate.hinC(dose.1/4, 190) + Calculate.hinC(dose.1/3, 250)
# lines(dose, SEA(dose), lty=2)
# lines(dose, Calculate.hinC(dose,190), col='green') # component 4
# lines(dose, Calculate.hinC(dose, 250), col='green') # component 3
# lines(dose, Calculate.hinC(dose, 70), col='green') # component 2
# lines(dose, Calculate.hinC(dose, 25), col='green') # component 1
# 
# # Example Plot 3: two HZE one low-LET
# d <- seq(0, .01, .0005); r <- c(1/20, 1/20, 9/10); L <- c(70, 173)
# plot(x = d, y = Calculate.hinC(dose.1 = d, L = 173), type = "l", xlab="dose",ylab="HG",bty='l',col='green',lwd=2)
# lines(x = d, y = Calculate.hinC(d, 70), col='green', lwd=2) # component 3
# lines(x = d, y = CalculateLOW.C(d, 0), col='green', lwd=2)
# lines(x = d, y = calculateComplexId(r, L, d = d, lowLET = TRUE)[, 2], col = 'red', lwd = 2)

################## I(d) calculator END ##################

#==============================================#
#==========Confidence Interval Part============#
#==============================================#

# Parameter initialization
d <- seq(0, .01, .0005); r <- c(1/20, 1/20, 9/10); L <- c(70, 173)
sampleNum = 1000
mod = 1              # 1 if HIN, 0 if HIT

# Set the pseudorandom seed
set.seed(100)

# helper function to generate samples
Generate_samples = function(N = sampleNum, model = mod, HINmodel = hinm, HITmodel = hitm, LOWmodel = LOW.m) {
  # Function to generate Monte Carlo samples for calculating CI
  # @params:   N              - numbers of sample
  #            model          - select HIN or HIT model
  #                             0 - HIT model
  #                             1 - HIN model
  #            HINmodel       - the input HIN model
  #            HITmodel       - the input HIN model
  #            LOWmodel       - the input LOW model
  monteCarloSamplesLow = rmvnorm(n = N, mean = coef(LOWmodel), sigma = vcov(LOWmodel))
  curveList = list(0)
  if (model) {
    monteCarloSamplesHin = rmvnorm(n = N, mean = coef(HINmodel), sigma = vcov(HINmodel))
  } else {
    monteCarloSamplesHit = rmvnorm(n = N, mean = coef(HITmodel), sigma = vcov(HITmodel))
  }
  for (i in 1:N) {
    if (model) {
      curveList[[i]] = calculateComplexId(r = r, L = L, d = d, aa1 = monteCarloSamplesHin[, 1][i], aa2 = monteCarloSamplesHin[, 2][i], kk1 = monteCarloSamplesHin[, 3][i], beta = monteCarloSamplesLow[, 1][i], lowLET = TRUE)
    } else {
      curveList[[i]] = calculateComplexId.te(r = r, L = L, d = d, aate1 = monteCarloSamplesHit[, 1][i], aate2 = monteCarloSamplesHit[, 2][i], beta = monteCarloSamplesLow[, 1][i], lowLET = TRUE)
    }
    print(paste("Currently at Monte Carlo step:", toString(i), "Total of", toString(N), "steps"))
  }
  return (curveList)
}

# Generate N randomly generated samples of parameters of HZE model.
curveList = Generate_samples()

Generate_CI = function(N = sampleNum, intervalLength = 0.95, d, doseIndex, r, L, HINmodel = hinm, HITmodel = hitm, LOWmodel = LOW.m, method = 0, sampleCurves = curveList, model = mod) {
  # Function to generate CI for the input dose.
  # @params:   N              - numbers of sample
  #            intervalLength - size of confidence interval
  #            d              - input dose
  #            r              - proportion of ion
  #            L              - LTE
  #            HINmodel       - the input HIN model
  #            HITmodel       - the input HIN model
  #            LOWmodel       - the input LOW model
  #            method         - select Naive or Monte Carlo Approach
  #                             0 - Naive
  #                             1 - Monte Carlo
  if (method) {
    # For each sample curve, evalute them at input dose, and sort.
    valueArr = vector(length = 0)
    for (i in 1:N) {
      valueArr = c(valueArr, sampleCurves[[i]][, 2][doseIndex])
    }
    valueArr = sort(valueArr)

    # Returning resulting CI
    return (c(valueArr[(1-intervalLength)/2*N], valueArr[(intervalLength + (1-intervalLength)/2)*N]))
  } else {
    #========= Naive =========#
    stdErrArrLow = summary(LOWmodel)$coefficients[, "Std. Error"]
    meanArrLow = summary(LOWmodel)$coefficients[, "Estimate"]
    if (model) {
      stdErrArrHin = summary(HINmodel)$coefficients[, "Std. Error"]
      meanArrHin = summary(HINmodel)$coefficients[, "Estimate"]
      upper = calculateComplexId(r = r, L = L, d = c(0, d), aa1 = meanArrHin["aa1"] + 2*stdErrArrHin["aa1"], aa2 = meanArrHin["aa2"] + 2*stdErrArrHin["aa2"], kk1 = meanArrHin["kk1"] + 2*stdErrArrHin["kk1"], beta = meanArrLow + 2*stdErrArrLow, lowLET = TRUE)[, 2][2]
      lower = calculateComplexId(r = r, L = L, d = c(0, d), aa1 = meanArrHin["aa1"] - 2*stdErrArrHin["aa1"], aa2 = meanArrHin["aa2"] - 2*stdErrArrHin["aa2"], kk1 = meanArrHin["kk1"] - 2*stdErrArrHin["kk1"], beta = meanArrLow - 2*stdErrArrLow, lowLET = TRUE)[, 2][2]
    } else {
      stdErrArrHit = summary(HITmodel)$coefficients[, "Std. Error"]
      meanArrHit = summary(HITmodel)$coefficients[, "Estimate"]
      upper = calculateComplexId.te(r = r, L = L, d = c(0, d), aate1 = meanArrHit["aate1"] + 2*stdErrArrHit["aate1"], aate2 = meanArrHit["aate2"] + 2*stdErrArrHit["aate2"], beta = meanArrLow + 2*stdErrArrLow, lowLET = TRUE)[, 2][2]
      lower = calculateComplexId.te(r = r, L = L, d = c(0, d), aate1 = meanArrHit["aate1"] - 2*stdErrArrHit["aate1"], aate2 = meanArrHit["aate2"] - 2*stdErrArrHit["aate2"], beta = meanArrLow - 2*stdErrArrLow, lowLET = TRUE)[, 2][2]
    }
    return (c(lower, upper))
  }
}

# Parameter initialization
if (mod) {
  mixderCurve = calculateComplexId(r, L, d = d, lowLET = TRUE)
} else {
  mixderCurve = calculateComplexId.te(r, L, d = d, lowLET = TRUE)
}
fourIonMIXDER = data.frame(d = mixderCurve[, 1], CA = mixderCurve[, 2])
numDosePoints = length(fourIonMIXDER$d)
naiveCI = matrix(nrow = 2, ncol = numDosePoints)
monteCarloCI = matrix(nrow = 2, ncol = numDosePoints)

# Calculate CI for each dose point
for (i in 1 : numDosePoints) {
  naiveCI[, i] = Generate_CI(d = fourIonMIXDER$d[i], r = r,  L = L)
  monteCarloCI[, i] = Generate_CI(doseIndex = i, r = r,  L = L, method = 1)
  print(paste("Iterating on dose points. Currently at step:", toString(i), "Total of", toString(numDosePoints), "steps."))
}

# Plot
mixderGraphWithNaiveCI = ggplot(data = fourIonMIXDER, aes(x = d, y = CA)) + geom_line(aes(y = CA), col = "red", size = 1) + geom_ribbon(aes(ymin = naiveCI[1, ], ymax = naiveCI[2, ]), alpha = .2)
mixderGraphWithMonteCarloCI = ggplot(data = fourIonMIXDER, aes(x = d, y = CA)) + geom_line(aes(y = CA), col = "red", size = 1) + geom_ribbon(aes(ymin = monteCarloCI[1, ], ymax = monteCarloCI[2, ]), alpha = .4)
print(mixderGraphWithNaiveCI)
print(mixderGraphWithMonteCarloCI)

mixderGraphWithNaiveAndMonteCarloCI = ggplot(data = fourIonMIXDER, aes(x = d, y = CA)) + geom_line(aes(y = CA), col = "red", size = 1) + geom_ribbon(aes(ymin = monteCarloCI[1, ], ymax = monteCarloCI[2, ]), alpha = .6) + geom_line(aes(y = CA), col = "red", size = 1) + geom_ribbon(aes(ymin = naiveCI[1, ], ymax = naiveCI[2, ]), alpha = .2)
print(mixderGraphWithNaiveAndMonteCarloCI)