from flask import abort

class Response:
    def __init__(self, ctx):
        self.remote_server = ctx.remote_server
        self.remote_search_url = ctx.remote_search_url
        self.annotation_limit = ctx.annotation_limit
        self.logger = ctx.logger


    def simple_template(self, q, page, items):
        dict = {
            "@context": "http://iiif.io/api/search/2/context.json",
            "id": f"{self.remote_search_url}?q={q}&page={page}",
            "type": "AnnotationPage",
            "items": items,
        }
        return dict

    def part_of(self, q, total, total_pages):
        first = f"{self.remote_search_url}?q={q}&page=0"
        last = f"{self.remote_search_url}?q={q}&page={total_pages}"
        dict = {
            "partOf": {
                "id": f"{self.remote_search_url}?q={q}",
                "type": "AnnotationCollection",
                "total": total,
                "first": {"id": first, "type": "AnnotationPage"},
                "last": {"id": last, "type": "AnnotationPage"}
            }
        }
        return dict

    def paged_template(self, q, page, total, items):
        start_index = page * self.annotation_limit
        total_pages = int(total / self.annotation_limit)
        dict = self.simple_template(q, page, items)
        dict.update(self.part_of(q, total, total_pages))
        if page > 0:
            dict["prev"] = f"{self.remote_search_url}?q={q}&page={page-1}"
        if page < total_pages:
            dict["next"] = f"{self.remote_search_url}?q={q}&page={page+1}"
        dict["start_index"] = start_index
        return dict

    def response(self, q, page, total, items):
        if total > self.annotation_limit:  # if paged response
            return self.paged_template(q, page, total, items)
        else:
            return self.simple_template(q, page, items)

    def annotations(self, q, page, total, data):
        try:
            items = []
            for item in data:
                items.append(item.json())
            result = self.response(q, page, total, items)
        except Exception as e:
            self.logger.error(f"failed to create annotation response: {repr(e)}")
            abort(500)
        else:
            return result
