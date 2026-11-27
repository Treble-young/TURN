extends SceneTree
func _initialize() -> void: check.call_deferred()
func check() -> void:
	var e = root.get_node("Expedition")
	for seed_value in range(100):
		e.start_run(seed_value)
		assert(e.active)
		for f in range(5):
			var rows = e.maps[f]
			assert(rows.size()==7 and rows[6]==[e.Kind.BOSS])
			var first = rows[0].duplicate()
			first.sort()
			assert(first == [e.Kind.BATTLE,e.Kind.BATTLE,e.Kind.ELITE])
			var gaps := []
			var services := {}; var events := {}; var wishes := {}; var counts := {}
			for row in range(1,6):
				for col in range(3):
					var kind: int = rows[row][col]
					counts[kind] = counts.get(kind,0)+1
					if kind == -1:
						for previous in gaps: assert(absi(previous-row)>1)
						gaps.append(row)
					var used: Dictionary = services if kind in [3,4] else (events if kind==5 else wishes)
					if kind in [3,4,5,6]:
						assert(not used.has(col)); used[col]=true
			assert(rows[5].has(-1))
			assert(gaps.size()==2 and counts[1]==2 and counts[6]==2 and counts[3]+counts[4]==3)
			assert(counts[0]+counts[5]==6 and counts[0] in [3,4] and counts[5] in [2,3])
			assert(e.crossings[f].size()==5 and e.lateral_crossings[f].size()==2)
			var occupied := {}
			for edge in e.crossings[f]:
				occupied[edge.x-1]=occupied.get(edge.x-1,0)+1
				assert(occupied[edge.x-1]<=2)
				assert(rows[edge.x-1][edge.y]!=-1 and rows[edge.x][edge.z]!=-1)
			for edge in e.lateral_crossings[f]:
				assert(edge.x > 0)
				occupied[edge.x]=occupied.get(edge.x,0)+1
				assert(occupied[edge.x]<=2)
			assert(e._all_nodes_connected(rows,e.crossings[f],e.lateral_crossings[f]))
		var snapshot = e.maps.duplicate(true)
		e.start_run(seed_value)
		assert(snapshot == e.maps)
	print("PASS: 100 seeds / 500 floors: exact pools, column/gap constraints, 5 diagonal + 2 lateral, max 2 edges/source-row, reachability, unique level assignments and determinism")
	quit()
