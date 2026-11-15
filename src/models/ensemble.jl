"""
Equal-weight ensemble of other forecasters. Members are fitted copies;
the ensemble forecast is the mean of member forecasts.
"""
mutable struct Ensemble <: AbstractForecaster
    members::Vector{AbstractForecaster}
end
Ensemble() = Ensemble(AbstractForecaster[])

Base.copy(m::Ensemble) = Ensemble([copy(x) for x in m.members])

fitted_values(m::Ensemble) = isempty(m.members) ? Float64[] : mean(hcat((fitted_values(x) for x in m.members)...); dims = 2)[:, 1]

function forecast(m::Ensemble, h::Int; dates = nothing, promo = nothing, kwargs...)
    isempty(m.members) && return zeros(h)
    return mean(hcat([forecast(x, h; dates = dates, promo = promo) for x in m.members]...); dims = 2)[:, 1]
end

"""
    fit_ensemble(templates, y, dates; kwargs...) -> Ensemble (fitted)

Fit each model template on the training data and wrap in an Ensemble.
Templates that fail to fit are skipped silently.
"""
function fit_ensemble(templates::Vector{<:AbstractForecaster}, y, dates; kwargs...)
    fitted = AbstractForecaster[]
    for t in templates
        try
            push!(fitted, fit(t, y, dates; kwargs...))
        catch
            # skip failing members
        end
    end
    return Ensemble(fitted)
end
