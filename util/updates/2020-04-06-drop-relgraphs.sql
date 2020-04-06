DROP TRIGGER vn_relgraph_notify ON vn;
DROP FUNCTION vn_relgraph_notify();

DROP TRIGGER producer_relgraph_notify ON producers;
DROP FUNCTION producer_relgraph_notify();

ALTER TABLE vn DROP COLUMN rgraph;
ALTER TABLE producers DROP COLUMN rgraph;
DROP TABLE relgraphs;
