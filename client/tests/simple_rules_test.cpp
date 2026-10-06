#include <nekobox/dataStore/SimpleRuleClassification.hpp>
#include <cstdlib>
#include <iostream>
using namespace SimpleRuleClassification;
int checks = 0;
void expect(Result r, Kind k, Action a = Direct) {
    ++checks;
    if (r.kind != k || (k != Custom && r.action != a)) {
        std::cerr << "Classification failed at case " << checks << '\n';
        std::exit(1);
    }
}
int main() {
    for (const auto field : {"domain", "domain_suffix", "domain_keyword", "domain_regex", "ip_cidr", "rule_set", "process_name", "process_path"}) {
        const auto kind = selectorKind(field);
        expect(classify({field, "action", "outbound"}, "route", -2, true), kind, Direct);
        expect(classify({field, "outbound"}, "route", -1, true), kind, Proxy);
        expect(classify({field, "outbound"}, "route", -3, true), kind, Block);
        expect(classify({field, "action"}, "reject", -2, true), kind, Block);
        expect(classify({field, "outbound"}, "route", 7, true), Custom);
        expect(classify({field}, "route", -2, true), Custom);
        expect(classify({field, "outbound"}, "route", -1, false), Custom);
    }
    for (const auto extra : {"port", "port_range", "network", "ip_version", "protocol", "inbound", "invert", "ip_is_private", "source_ip_cidr", "source_port", "process_path_regex", "method", "no_drop", "override_address", "override_port", "future_condition", "type", "rules"}) {
        expect(classify({"domain", "action", "outbound", extra}, "route", -1, true), Custom);
    }
    expect(classify({"domain", "ip_cidr", "rule_set", "outbound"}, "route", -2, true), Address);
    expect(classify({"domain", "process_name", "outbound"}, "route", -1, true), Custom);
    expect(classify({"process_path", "process_name", "outbound"}, "route", -1, true), Custom);
    expect(classify({"process_name", "action", "outbound"}, "reject", -2, true), Custom);
    expect(classify({"protocol", "action"}, "hijack-dns", -2, true), Custom);
    expect(classify({"domain", "action"}, "sniff", -2, true), Custom);
    expect(classify({"outbound"}, "route", -1, true), Custom);
    expect(classify({}, "route", -2, true), Custom);
    std::cout << checks << " classification cases passed\n";
}
