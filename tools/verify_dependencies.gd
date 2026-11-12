extends SceneTree
func _initialize():
 var report=load(get_script().resource_path.get_base_dir().path_join('dependency_closure.gd')).verify()
 var out=OS.get_environment('DEPENDENCY_REPORT');assert(not out.is_empty())
 FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report))
 print('ACTUAL_PCK_RECURSIVE_DEPENDENCY_CLOSURE_PASS guards=',report.guard_count,' resources=',report.visited.size(),' edges=',report.edges.size());quit()
