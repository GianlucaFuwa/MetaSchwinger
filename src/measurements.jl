module Measurements

	import ..System_parameters:Params
	import ..System_parameters:set_params
    import ..Gaugefields:Gaugefield,plaquette
    import ..Metadynamics:Bias_potential,penalty_potential

    defaultmeasures = Array{Dict,1}(undef,2)
    for i=1:length(defaultmeasures)
        defaultmeasures[i] = Dict()
    end
	
	defaultmeasures[1]["methodname"] = "Continuous_charge"
    defaultmeasures[1]["measure_every"] = 1
    defaultmeasures[2]["methodname"] = "Topological_charge"
    defaultmeasures[2]["measure_every"] = 1

    struct Measurement_set
        nummeas::Int64
        meas_calls::Array{Dict,1}
        meas_files::Array{IOStream,1}

        function Measurement_set(measure_dir;meas_calls=defaultmeasures)
            nummeas = length(meas_calls)
            meas_files = Array{IOStream,1}(undef,nummeas)
            for i=1:nummeas
                method = meas_calls[i]
                
                meas_overwrite = "w"
                if method["methodname"] == "Plaquette"
                    meas_files[i] = open(measure_dir*"/Plaquette.txt",meas_overwrite)
                elseif method["methodname"] == "Action"
                    meas_files[i] = open(measure_dir*"/Action.txt",meas_overwrite)
                elseif method["methodname"] == "Continuous_charge"
                    meas_files[i] = open(measure_dir*"/Continuous_charge.txt",meas_overwrite)
                elseif method["methodname"] == "Topological_charge"
                    meas_files[i] = open(measure_dir*"/Topological_charge.txt",meas_overwrite)
                elseif method["methodname"] == "Topological_susceptibility"
                    meas_files[i] = open(measure_dir*"/Topological_susceptibility.txt",meas_overwrite)
                else 
                    error("$(method["methodname"]) is not supported")
                end
            end
            return new(nummeas,meas_calls,meas_files)
        end
    end

    function measurements(itr,field::Gaugefield,measset::Measurement_set)
        for i = 1:measset.nummeas
            method = measset.meas_calls[i]
            measfile = measset.meas_files[i]
            if itr % method["measure_every"] == 0
                if method["methodname"] == "Plaquette"
                    plaq = 0.0
                    for nx=1:field.Nx
                        for nt=1:field.Nt
                            plaq += plaquette(field.g,nx,nt)
                        end
                    end
                    plaq /= field.Nx*field.Nt
                    println(measfile,"$itr $plaq # plaq")
                elseif method["methodname"] == "Action"
                    s = field.S
                    println(measfile,"$itr $s # action")
                elseif method["methodname"] == "Continuous_charge"
                    q = field.Q
                    println(measfile,"$itr $q # continuous charge")
                elseif method["methodname"] == "Topological_charge"
                    q = calc_topcharge(field)
                    println(measfile,"$itr $q # topological charge")
                elseif method["methodname"] == "Topological_susceptibility"
                    χ = calc_topcharge(field)^2
                    println(measfile,"$itr $χ # topological susceptibility")
                else 
                    error("$(method["methodname"]) is not supported")
                end
                flush(measfile)
            end
        end
        return nothing
    end

    function build_measurements(itr,field::Gaugefield,buildmeasures::Measurement_set)
        for i = 1:buildmeasures.nummeas
            method = buildmeasures.meas_calls[i]
            measfile = buildmeasures.meas_files[i]
            if itr % method["measure_every"] == 0
                if method["methodname"] == "Continuous_charge"
                    q = field.Q
                    println(measfile,"$itr $q # continuous charge")
                elseif method["methodname"] == "Topological_charge"
                    q = calc_topcharge(field)
                    println(measfile,"$itr $q # topological charge")
                end
                flush(measfile)
            end
        end
        return nothing
    end
    
    function calc_topcharge(field::Gaugefield)
        q = complex(0.)
        for nx=1:field.Nx
            for nt=1:field.Nt
                q += log(exp(plaquette(field.g,nx,nt)im))
            end
        end
        return round(Int,imag(q)/2pi,RoundNearestTiesAway)
    end

    function calc_weights(q_vals::Array{Float64,1},b::Bias_potential)
        @inline index(q,qmin,dq) = round(Int,(q-qmin)/dq+0.5,RoundNearestTiesAway)
        weights = zeros(length(q_vals))
        for i=1:length(q_vals)
            idx = index(q_vals[i],b.Qmin,b.δq)
            weights[i] = exp(b.values[idx]+penalty_potential(q_vals[i],b.Qmin_thr,b.Qmax_thr,b.k))
        end
        return weights
    end
    
end