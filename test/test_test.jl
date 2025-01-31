using Test
using MPI

if get(ENV,"JULIA_MPI_TEST_ARRAYTYPE","") == "CuArray"
    import CUDA
    ArrayType = CUDA.CuArray
else
    ArrayType = Array
end

MPI.Init()

comm = MPI.COMM_WORLD
size = MPI.Comm_size(comm)
rank = MPI.Comm_rank(comm)

dst = mod(rank+1, size)
src = mod(rank-1, size)

N = 32

send_mesg = ArrayType{Float64}(undef,N)
recv_mesg = ArrayType{Float64}(undef,N)
recv_mesg_expected = ArrayType{Float64}(undef,N)
fill!(send_mesg, Float64(rank))
fill!(recv_mesg_expected, Float64(src))

rreq = MPI.Irecv!(recv_mesg, src,  src+32, comm)
sreq = MPI.Isend(send_mesg, dst, rank+32, comm)

reqs = [sreq,rreq]

(inds,stats) = MPI.Waitsome!(reqs)
@test !isempty(inds)
for ind in inds
    (onedone,stat) = MPI.Test!(reqs[ind])
    @test onedone
    @test stat.source == MPI.MPI_ANY_SOURCE
    @test stat.tag == MPI.MPI_ANY_TAG
    @test stat.error == MPI.MPI_SUCCESS
end

(done, ind, stats) = MPI.Testany!(reqs)
if done && ind != 0
    (onedone,stat) = MPI.Test!(reqs[ind])
    @test onedone
    @test stat.source == MPI.MPI_ANY_SOURCE
    @test stat.tag == MPI.MPI_ANY_TAG
    @test stat.error == MPI.MPI_SUCCESS
end

MPI.Waitall!(reqs)

(inds, stats) = MPI.Waitsome!(reqs)
@test isempty(inds)
@test isempty(stats)
(inds, stats) = MPI.Testsome!(reqs)
@test isempty(inds)
@test isempty(stats)

MPI.Finalize()
@test MPI.Finalized()
