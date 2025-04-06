package main

Queue :: struct($T: typeid, $N: int) {
	items: [N]T,
	first: int,
	count: int,
}

push :: proc(q: ^Queue($T, $N), x: T) -> (ok: bool) {
	if full(q) do return false
	i := (q.first + q.count) % N
	q.items[i] = x
	q.count += 1
	return true
}

pop :: proc(q: ^Queue($T, $N)) -> (x: T, ok: bool) {
	if empty(q) do return
	x = q.items[q.first]
	q.first = (q.first + 1) % N
        q.count -= 1
	ok = true
	return
}

peek :: proc(q: ^Queue($T, $N)) -> (x: T, ok: bool) {
	if empty(q) do return
	x = q.items[q.first]
	ok = true
	return
}

empty :: proc(q: ^Queue($T, $N)) -> bool {
	return q.count <= 0
}

full :: proc(q: ^Queue($T, $N)) -> bool {
	return q.count >= N
}
