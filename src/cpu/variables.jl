mu = Array{p.FloatPrecision}(p.mu)  # external input

#synaptic time constants
invtauedecay = p.FloatPrecision(1/p.tauedecay)
invtauidecay = p.FloatPrecision(1/p.tauidecay)
if typeof(p.taudecay_plastic)<:Number
    invtaudecay_plastic = p.FloatPrecision(1/p.taudecay_plastic)
else
    invtaudecay_plastic = Vector{p.FloatPrecision}(inv.(p.taudecay_plastic))
end

#spike thresholds
thresh = Vector{p.FloatPrecision}(undef, p.Ncells)
thresh[1:p.Ne] .= p.threshe
thresh[(1+p.Ne):p.Ncells] .= p.threshi

#membrane time constants
tau = Vector{p.FloatPrecision}(undef, p.Ncells)
tau[1:p.Ne] .= p.taue
tau[(1+p.Ne):p.Ncells] .= p.taui

maxTimes = round(Int,p.maxrate*p.train_time/1000)  # maximum number of spikes times to record
times = Array{Float64}(undef, p.Ncells, maxTimes)  # times of recurrent spikes throughout trial
ns = Vector{p.IntPrecision}(undef, p.Ncells)       # number of recurrent spikes in trial
times_ffwd = Array{Float64}(undef, p.Lffwd, maxTimes)  # times of feed-forward spikes throughout trial
ns_ffwd = Vector{p.IntPrecision}(undef, p.Lffwd)       # number of feed-forward spikes in trial

forwardInputsE = Vector{p.FloatPrecision}(undef, p.Ncells)     # excitatory synaptic currents to neurons via balanced connections at one time step
forwardInputsI = Vector{p.FloatPrecision}(undef, p.Ncells)     # inhibitory synaptic currents to neurons via balanced connections at one time step
forwardInputsP = Vector{p.FloatPrecision}(undef, p.Ncells)     # synaptic currents to neurons via plastic connections at one time step
forwardInputsEPrev = Vector{p.FloatPrecision}(undef, p.Ncells) # copy of forwardInputsE from previous time step
forwardInputsIPrev = Vector{p.FloatPrecision}(undef, p.Ncells) # copy of forwardInputsI from previous time step
forwardInputsPPrev = Vector{p.FloatPrecision}(undef, p.Ncells) # copy of forwardInputsP from previous time step
forwardSpike = Vector{p.FloatPrecision}(undef, p.Ncells)       # spikes emitted by each recurrent neuron at one time step
forwardSpikePrev = Vector{p.FloatPrecision}(undef, p.Ncells)   # copy of forwardSpike from previous time step
ffwdSpike = Vector{p.FloatPrecision}(undef, p.Lffwd)           # spikes emitted by each feed-forward neuron at one time step
ffwdSpikePrev = Vector{p.FloatPrecision}(undef, p.Lffwd)       # copy of ffwdSpike from previous time step

xedecay = Vector{p.FloatPrecision}(undef, p.Ncells)          # synapse-filtered excitatory current (i.e. filtered version of forwardInputsE)
xidecay = Vector{p.FloatPrecision}(undef, p.Ncells)          # synapse-filtered inhibitory current (i.e. filtered version of forwardInputsI)
xpdecay = Vector{p.FloatPrecision}(undef, p.Ncells)          # synapse-filtered plastic current (i.e. filtered version of forwardInputsP)
synInputBalanced = Vector{p.FloatPrecision}(undef, p.Ncells) # sum of xedecay and xidecay (i.e. synaptic current from the balanced connections)
synInput = Vector{p.FloatPrecision}(undef, p.Ncells)         # sum of xedecay and xidecay (i.e. synaptic current from the balanced connections)
r = Vector{p.FloatPrecision}(undef, p.Ncells)                # synapse-filtered recurrent spikes (i.e. filtered version of forwardSpike)
s = Vector{p.FloatPrecision}(undef, p.Lffwd)                 # synapse-filtered feed-forward spikes (i.e. filtered version of ffwdSpike)

bias = Vector{p.FloatPrecision}(undef, p.Ncells)             # total external input to neurons

lastSpike = Array{Float64}(undef, p.Ncells)  # last time a neuron spiked

plusone = p.FloatPrecision(1.0)
exactlyzero = p.FloatPrecision(0.0)
PScale = p.FloatPrecision(p.PScale)

vre = p.FloatPrecision(p.vre)  # reset voltage

uavg = zeros(p.FloatPrecision, p.Ncells)  # average synaptic input
utmp = Matrix{p.FloatPrecision}(undef, p.Nsteps - round(Int, 1000/p.dt), 1000)

raug = Matrix{p.FloatPrecision}(undef, p.Lexc+p.Linh+p.Lffwd, Threads.nthreads())
k = Matrix{p.FloatPrecision}(undef, p.Lexc+p.Linh+p.Lffwd, Threads.nthreads())
delta = Matrix{p.FloatPrecision}(undef, p.Lexc+p.Linh+p.Lffwd, Threads.nthreads())
v = Vector{p.FloatPrecision}(undef, p.Ncells)  # membrane voltage
noise = Vector{p.FloatPrecision}(undef, p.Ncells)  # actual noise added at current time step
sig = fill(p.FloatPrecision(p.sig), p.Ncells)  # std dev of the Gaussian noise

rndFfwd = Vector{p.FloatPrecision}(undef, p.Lffwd)  # uniform noise to generate Poisson feed-forward spikes

learn_step = round(Int, p.learn_every/p.dt)
