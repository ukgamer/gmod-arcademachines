ARCADE = ARCADE or {}

function ARCADE:WithinBounds(point, vecs)
    local b1, b2, _, b4, t1, _, t3, _ = unpack(vecs)

    local dir1 = (t1 - b1)
    local size1 = dir1:Length()
    dir1 = dir1 / size1

    local dir2 = (b2 - b1)
    local size2 = dir2:Length()
    dir2 = dir2 / size2

    local dir3 = (b4 - b1)
    local size3 = dir3:Length()
    dir3 = dir3 / size3

    local cube3d_center = (b1 + t3) / 2.0

    local dir_vec = point - cube3d_center

    local res1 = math.abs(dir_vec:Dot(dir1)) * 2 < size1
    local res2 = math.abs(dir_vec:Dot(dir2)) * 2 < size2
    local res3 = math.abs(dir_vec:Dot(dir3)) * 2 < size3

    return res1 and res2 and res3
end