using StatsPlots,Dates,JLD2,Statistics,Optim,Parameters,Distributions,DataFrames,CSV
using Plots.PlotMeasures,OrdinaryDiffEq,DiffEqCallbacks
import KenyaCoVSD
include("fitting_methods.jl");
include("plotting_methods.jl");
## Load the collated fits
@load("data/N_kenya.jld2")
@load("data/linelist_data_with_pos_neg_20feb_to_27apr_c_age.jld2")
@load("data/serological_data_with_20feb_to_31dec_age.jld2")
@load("data/serological_data_with_20feb_to_10Mar2021_age.jld2")
@load("data/cleaned_linelist20210521_deaths_c__date_of_lab_confirmation.jld2")
@load("data/p_ID.jld2")
@load("forecasts/condensed_county_forecasts.jld2")
@load("data/rel_sero_detection_after_infection.jld2")
@load("modelfits/Nairobi_model.jld2")
nai_model = model
@load("data/cleaned_linelist20210521_c.jld2")#<--- Positive tests only looking ahead of linelist we fitted to


kenya_owid = DataFrame(CSV.File("data/kenya_owid.csv"))
owid_xs = [(Date(d,DateFormat("dd/mm/yyyy")) - Date(2020,2,20)).value for d in kenya_owid.date]
owid_cases = kenya_owid.new_cases
owid_cases[ismissing.(owid_cases)] .= 0
owid_deaths = kenya_owid.new_deaths
owid_deaths[ismissing.(owid_deaths)] .= 0
june1day = (Date(2021,6,1) - Date(2020,2,24)).value

# gr()
# plotlyjs()
## PCR plot --- Kenya wide


n = size(condensed_county_forecasts[1].pred.mean_PCR_forecast,1)
n_1 = size(linelist_data_with_pos_neg.cases,1) - 14

kenya_pcr_forecast = zeros(n)
var_kenya_pcr_forecast =zeros(n)

for fit in condensed_county_forecasts
     kenya_pcr_forecast .+= fit.pred.mean_PCR_forecast[:]
     var_kenya_pcr_forecast .+= fit.pred.std_PCR_forecast[:].^2
end
# std_kenya_pcr_forecast = sqrt.(std_kenya_pcr_forecast)
kenya_pcr_forecast_mv_av = weekly_mv_av(kenya_pcr_forecast)
kenya_pcr_forecast_mv_av_var = weekly_mv_av(var_kenya_pcr_forecast)
kenya_pos = sum(linelist_data_with_pos_neg.cases[:,:,:,1],dims = [2,3])[:]
kenya_pos_mv_av = weekly_mv_av(kenya_pos[1:(end-14)])

xticktimes = [((Date(2020,2,1) + Month(k))- Date(2020,2,24)).value for k = 1:18 ]
xticklabs = [monthname(k)[1:3]*"/20" for k = 3:12]
xticklabs = vcat(xticklabs,[monthname(k)[1:3]*"/21" for k = 1:8])

gr()
PCR_plt = scatter(kenya_pos[1:(end-14)],
        ms = 4,markerstrokewidth = 0,color = :grey,alpha = 0.5,
        xticks = (xticktimes,xticklabs),
        lab = "Daily cases: Kenyan linelist (used for fitting)",legend = :topleft,
        title = "Kenyan PCR test positives",
        xlims = (-5,june1day),
        ylabel = "Daily PCR-confirmed cases",
        size = (1100,500),dpi = 250,
        legendfont = 13,titlefont = 24,tickfontsize=10,guidefont = 18,
        left_margin = 10mm,right_margin = 7.5mm)

plot!(PCR_plt,(1+3):(length(kenya_pos_mv_av)+3),kenya_pos_mv_av,
        color = :black,lw = 3,
        lab = "Daily cases: 7 day mv-av (used in fitting)")

# plot!(PCR_plt,owid_xs[4:(end-3)],weekly_mv_av(owid_cases),color = :red,lw = 3,lab = "Daily cases: Kenyan MoH (7 day mv-av)")
# plot!(PCR_plt,(n_1+1):(size(linelist_data.cases,1)-3),weekly_mv_av(sum(linelist_data.cases,dims = 2)[:])[(n_1+1):end],color = :red,lw = 3,lab = "Daily cases: Kenyan MoH (7 day mv-av)")
smooth_cases_lookahead = weekly_mv_av(sum(linelist_data.cases[(n_1-2):end,:],dims = 2)[:])
plot!(PCR_plt,(length(kenya_pos_mv_av)+4):(length(kenya_pos_mv_av)+3+length(smooth_cases_lookahead)),smooth_cases_lookahead,
        color = :black,lw = 3,ls = :dash,
        lab = "Daily cases: 7 day mv-av (not used in fitting)")

plot!(PCR_plt,4:(n-3),kenya_pcr_forecast_mv_av,ribbon = 9*sqrt.(kenya_pcr_forecast_mv_av_var),
        color = :red, lw = 3,lab = "Model fit and forecast (7 day mv-av)",
        fillalpha = 0.4)

# savefig(PCR_plt,"plots/kenya_cases.pdf")

## Kenyan deaths

n = size(condensed_county_forecasts[1].pred.mean_PCR_forecast,1)

kenya_deaths_forecast = zeros(n)
var_kenya_deaths_forecast = zeros(n)

for fit in condensed_county_forecasts
     kenya_deaths_forecast .+= fit.pred.mean_deaths[:]
     var_kenya_deaths_forecast .+= fit.pred.std_deaths[:].^2
end

kenya_deaths_forecast_mv_av = weekly_mv_av(kenya_deaths_forecast)
kenya_deaths_forecast_mv_av_var = weekly_mv_av(var_kenya_deaths_forecast)
kenya_deaths = sum(deaths_data.deaths,dims = 2)[1:(end-14)]
kenya_deaths_mv_av = weekly_mv_av(kenya_deaths)

xticktimes = [((Date(2020,2,1) + Month(k))- Date(2020,2,24)).value for k = 1:18 ]
xticklabs = [monthname(k)[1:3]*"/20" for k = 3:12]
xticklabs = vcat(xticklabs,[monthname(k)[1:3]*"/21" for k = 1:8])

deaths_plt = scatter(kenya_deaths,
        ms = 4,markerstrokewidth = 0,color = :grey,alpha = 0.5,
        xticks = (xticktimes,xticklabs),
        lab = "Daily deaths: Kenyan linelist",legend = :topleft,
        title = "Kenyan PCR-confirmed deaths",
        xlims = (-5,june1day),ylims = (0,50),
        ylabel = "Daily PCR-confirmed deaths",
        size = (1100,500),dpi = 250,
        legendfont = 13,titlefont = 24,xtickfontsize=10,ytickfontsize=13,guidefont = 18,
        left_margin = 10mm,right_margin = 7.5mm)

plot!(deaths_plt,(1+3):(length(kenya_deaths_mv_av)+3),kenya_deaths_mv_av,
        color = :black,lw = 3,
        lab = "Daily deaths: 7 day mv-av")

# plot!(deaths_plt,owid_xs[4:(end-3)],weekly_mv_av(owid_deaths),color = :red,lw = 3,lab = "Daily cases: Kenyan MoH (7 day mv-av)")

plot!(deaths_plt,4:(n-3),kenya_deaths_forecast_mv_av,ribbon = 9*sqrt.(kenya_deaths_forecast_mv_av_var),
        color = :green, lw = 5, ls = :dot,lab = "Model fit and forecast (7 day mv-av)")

plot!(deaths_plt,(1+3):(length(kenya_deaths_mv_av)+3),cumsum(kenya_deaths_mv_av),
        xticks = (xticktimes[4:4:end],xticklabs[4:4:end]),
        xlims = (-5,june1day),
        color = :black,lw = 3,
        grid = nothing,
        inset = (1,bbox(0.35, -0.25, 0.25, 0.25, :center)),
        lab="",
        subplot = 2,
        title = "Cumulative confirmed deaths",
        bg_inside = nothing)

# plot!(deaths_plt,owid_xs[4:(end-3)],cumsum(weekly_mv_av(owid_deaths)),
#         color = :red,lw = 3,lab = "",
#         subplot = 2)

plot!(deaths_plt,4:(n-3),cumsum(kenya_deaths_forecast_mv_av),
        xlims = (-5,june1day),color = :green, lw = 5, ls = :dot,lab = "",subplot=2)

# savefig(deaths_plt,"plots/kenya_deaths.pdf")


## Kenya Serology plot
# plotlyjs()
gr()
xticktimes = [((Date(2020,2,1) + Month(k))- Date(2020,2,24)).value for k = 1:18 ]
xticklabs = [monthname(k)[1:3]*"/20" for k = 3:12]
xticklabs = vcat(xticklabs,[monthname(k)[1:3]*"/21" for k = 1:8])

n = size(condensed_county_forecasts[1].pred.mean_PCR_forecast,1)
#Group the serology by week
zeropadtomonday = dayofweek(Date(2020,2,20)) - 1
kenya_sero_pos_rnd1_2 = vcat(zeros(zeropadtomonday),
                        sum(serological_data.serodata[:,:,:,1],dims = [2,3])[:])
kenya_sero_neg_rnd1_2 = vcat(zeros(zeropadtomonday),
                        sum(serological_data.serodata[:,:,:,2],dims = [2,3])[:])
kenya_weekly_sero_pos_rnd1_2 = [sum(grp) for grp in Iterators.partition(kenya_sero_pos_rnd1_2,7)]
kenya_weekly_sero_total_rnd1_2 = [sum(grp) for grp in Iterators.partition(kenya_sero_pos_rnd1_2.+kenya_sero_neg_rnd1_2,7)]

kenya_sero_pos_rnd3 = vcat(zeros(zeropadtomonday),
                        sum(serology_data.sero[:,:,:,1],dims = [2,3])[:])
kenya_sero_neg_rnd3 = vcat(zeros(zeropadtomonday),
                        sum(serology_data.sero[:,:,:,2],dims = [2,3])[:])
kenya_weekly_sero_pos_rnd3 = [sum(grp) for grp in Iterators.partition(kenya_sero_pos_rnd3,7)]
kenya_weekly_sero_total_rnd3 = [sum(grp) for grp in Iterators.partition(kenya_sero_pos_rnd3.+kenya_sero_neg_rnd3,7)]

#Jeffery intervals
seroidxs = kenya_weekly_sero_total_rnd3 .> 0
# rnd_1_2idx =
uerr = [invlogcdf(Beta(pos + 0.5,kenya_weekly_sero_total_rnd3[k] - pos + 0.5),log(0.975)) - pos/kenya_weekly_sero_total_rnd3[k] for (k,pos) in enumerate(kenya_weekly_sero_pos_rnd3) ]
lerr = [pos/kenya_weekly_sero_total_rnd3[k] - invlogcdf(Beta(pos + 0.5,kenya_weekly_sero_total_rnd3[k] - pos + 0.5),log(0.025)) for (k,pos) in enumerate(kenya_weekly_sero_pos_rnd3) ]


total_sero_tests_rnds_1_2 = sum(serological_data.serodata)
total_sero_tests= sum(serology_data.sero)

seroreversionrate = 1/(1.33*365)
seroreversionrate2 = 1/(0.595*365)
sero_array = nai_model.sero_sensitivity.*vcat(rel_sero_array_26days[1:30],[(1-seroreversionrate)^k for k in 1:600])
1/(0.595*365)
sero_array_nw = nai_model.sero_sensitivity.*vcat(rel_sero_array_26days[1:30],[1.0 for k in 1:600])


kenya_serology_forecast = zeros(n)
var_kenya_serology_forecast = zeros(n)
kenya_infections_forecast = zeros(n)
kenya_infections_forecast_weighted = zeros(n)
var_kenya_infections_forecast = zeros(n)
kenya_serology_forecast_nw = zeros(n)


test_weighted_kenya_serology_forecast = zeros(n)
test_weighted_var_kenya_serology_forecast = zeros(n)


for fit in condensed_county_forecasts
     county_sero_pos = KenyaCoVSD.simple_conv(fit.pred.mean_incidence₁ .+ fit.pred.mean_incidence₂,sero_array)
     county_sero_pos_nw = fit.pred.mean_serocoverted₁ .+ fit.pred.mean_serocoverted₂
     kenya_infections_forecast .+= cumsum(fit.pred.mean_incidence₁ .+ fit.pred.mean_incidence₂)
     var_kenya_infections_forecast .+= cumsum((fit.pred.std_incidence₁ .+ fit.pred.std_incidence₂).^2)
     county_test_weight = sum(serological_data.serodata[:,serological_data.areas .== uppercase(fit.name),:,:])/total_sero_tests_rnds_1_2
        # county_test_weight = sum(N_kenya[:,fit.name])/sum(N_kenya)
     test_weighted_kenya_serology_forecast .+= county_sero_pos.*(county_test_weight/sum(N_kenya[:,fit.name]))
     kenya_serology_forecast_nw .+= county_sero_pos_nw.*(county_test_weight/sum(N_kenya[:,fit.name]))
     var_kenya_serology_forecast .+= ((county_test_weight/sum(N_kenya[:,fit.name]))^2 ).*(fit.pred.std_serocoverted₁.^2 .+ fit.pred.std_serocoverted₂.^2)

end


xs_mondays = [-3 + (k-1)*7 for k = 1:length(kenya_weekly_sero_total_rnd3)]
rnd1_2_idxs = xs_mondays .< 300
rnd3_idxs = .~rnd1_2_idxs

plt_sero = scatter(xs_mondays[seroidxs.*rnd1_2_idxs],kenya_weekly_sero_pos_rnd3[seroidxs.*rnd1_2_idxs]./kenya_weekly_sero_total_rnd3[seroidxs.*rnd1_2_idxs],
        lab = "Weekly KNBTS: rounds 1 and 2 (used in fitting)",
        legend = :topleft,
        yerr = (lerr[seroidxs.*rnd1_2_idxs],uerr[seroidxs.*rnd1_2_idxs]),
        xticks = (xticktimes,xticklabs),
        title = "Kenyan overall population exposure",
        size = (1100,500),dpi = 250,
        xlims = xlims = (-5,june1day), ylims = (-0.025,1),
        ylabel = "Proportion of population",
        legendfont = 10,titlefont = 24,xtickfontsize=10,ytickfontsize=13,guidefont = 18,
        left_margin = 10mm,right_margin = 7.5mm)

scatter!(plt_sero,xs_mondays[seroidxs.*rnd3_idxs],kenya_weekly_sero_pos_rnd3[seroidxs.*rnd3_idxs]./kenya_weekly_sero_total_rnd3[seroidxs.*rnd3_idxs],
        yerr = (lerr[seroidxs.*rnd3_idxs],uerr[seroidxs.*rnd3_idxs]),
        lab = "Weekly KNBTS: round 3 (not used in fitting)")
plot!(plt_sero,kenya_serology_forecast_nw,lw = 2,color = :green,
        ribbon = 3*sqrt.(var_kenya_serology_forecast),
        lab = "Model fit: seropositivity (test weighted, no seroreversion)" )
plot!(plt_sero,test_weighted_kenya_serology_forecast,lw = 2,ls = :dash,color = :green,
        lab = "Model fit: seropositivity (test weighted, with seroreversion)" )


plot!(plt_sero,kenya_infections_forecast./sum(N_kenya),
        ribbon = 9*sqrt.(var_kenya_infections_forecast)./sum(N_kenya),
        lab = "Model fit: Overall Kenyan population exposure",
        color = :red)

# savefig(plt_sero,"plots/kenya_sero.pdf")

## Kenyan incidence

kenya_group1_incidence = zeros(n)
var_kenya_group1_incidence = zeros(n)
kenya_group2_incidence = zeros(n)
var_kenya_group2_incidence = zeros(n)




for fit in condensed_county_forecasts
     kenya_group1_incidence .+= fit.pred.mean_incidence₁
     var_kenya_group1_incidence .+= fit.pred.std_incidence₁.^2
     kenya_group2_incidence .+= fit.pred.mean_incidence₂
     var_kenya_group2_incidence .+= fit.pred.std_incidence₂.^2
end

#Remove the callback positions
deleteat!(kenya_group1_incidence,kenya_group1_incidence.==0)
deleteat!(var_kenya_group1_incidence,var_kenya_group1_incidence.==0)
deleteat!(kenya_group2_incidence,kenya_group2_incidence.==0)
deleteat!(var_kenya_group2_incidence,var_kenya_group2_incidence.==0)


plt_inc = plot(kenya_group1_incidence./1e5,
        lab = "Daily incidence: Lower SES",
        legend = :topleft,
        ribbon = 3*sqrt.(var_kenya_group1_incidence)./1e5,
        xticks = (xticktimes,xticklabs),
        title = "Kenyan transmission rates by SES group",
        size = (1100,500),dpi = 250,
        xlims = (-5,june1day),
        ylabel = "Daily infections (100,000s)",
        legendfont = 13,titlefont = 24,xtickfontsize=10,ytickfontsize=13,guidefont = 18,
        left_margin = 10mm,right_margin = 7.5mm)

plot!(plt_inc,kenya_group2_incidence./1e5,
        lab = "Daily incidence: Higher SES",
        legend = :topleft,
        ribbon = 3*sqrt.(var_kenya_group2_incidence)./1e5)

# savefig(plt_inc,"plots/kenya_incidence_SES.pdf")

## Rt plots
@load("modelfits/Nairobi_model.jld2")
nairobi_model = deepcopy(model)
@load("modelfits/Mombasa_model.jld2")
mombasa_model = deepcopy(model)
@load("modelfits/Kiambu_model.jld2")
kiambu_model = deepcopy(model)
@load("modelfits/Mandera_model.jld2")
mandera_model = deepcopy(model)


Rt_plt_nai = plot_Rt_both_SES_groups(nairobi_model,Date(2021,8,1))
Rt_plt_mom = plot_Rt_both_SES_groups(mombasa_model,Date(2021,8,1))
Rt_plt_kiambu= plot_Rt_both_SES_groups(kiambu_model,Date(2021,8,1))
Rt_plt_mandera= plot_Rt_both_SES_groups(mandera_model,Date(2021,8,1))

savefig(Rt_plt_nai,"plots/Rt_nai.pdf")
savefig(Rt_plt_mom,"plots/Rt_mom.pdf")
savefig(Rt_plt_kiambu,"plots/Rt_kiambu.pdf")
savefig(Rt_plt_mandera,"plots/Rt_mandera.pdf")
