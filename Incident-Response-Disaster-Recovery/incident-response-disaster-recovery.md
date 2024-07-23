## Crowdstrike or on strike? Disaster recovery and prep.

**Incident Response & Disaster Recovery for Sys Admins: A Practical Guide (Lessons from CrowdStrike)**

**1\. The Importance of IR & DR in the Age of Cloud Services**

- **A.** Dependence on Cloud Vendors:
  - i. Modern IT relies heavily on cloud services (Office 365, Azure, etc.).
  - ii. Vendor outages (like CrowdStrike) can have widespread impact on your organization. Learn more about vendor risk management:
    - **NIST Special Publication 800-161 Revision 1:** <https://csrc.nist.gov/publications/detail/sp/800-161/rev-1/final>
- **B.** Evolving Threat Landscape:
  - i. Cyberattacks, ransomware, and other threats are constantly evolving.
  - ii. Your IR/DR plans must be agile and adaptable — and you should **test them regularly** and make changes as necessary. Stay informed about the latest threats:
    - <https://www.cisa.gov/uscert>
- **C.** Business Continuity:
  - i. IR/DR are crucial for minimizing downtime and ensuring business operations continue.
  - ii. Failure to prepare can result in significant financial losses and reputational damage. Explore business continuity planning:
    - <https://www.ready.gov/business>

**2\. Incident Response Lifecycle**

- **A.** Preparation:
  - i. Assemble a cross-functional Incident Response Team (IRT). See example IRT roles and responsibilities:
    - Tabletop exercises with key players
  - ii. Develop a comprehensive Incident Response Plan (IRP). Utilize a template:
    - <https://frsecure.com/incident-response-plan-template/>
  - iii. Establish clear communication channels.
  - iv. Practice the IRP with drills and simulations.
- **B.** Identification:
  - i. Implement robust monitoring and alerting systems for early detection.
  - ii. Leverage endpoint detection and response (EDR) tools and SIEM solutions.
  - iii. Train staff to recognize signs of incidents. Check out NIST's guide:
    - <https://www.nist.gov/publications/computer-security-incident-handling-guide>
- **C.** Containment:
  - i. Isolate affected systems and networks.
  - ii. Stop the spread of malicious activity.
  - iii. Prevent further data loss or damage.
- **D.** Eradication:
  - i. Remove malware, patch vulnerabilities, and clean affected systems.
  - ii. Verify the effectiveness of remediation actions.
- **E.** Recovery:
  - i. Restore systems and data from backups.
  - ii. Test restored systems before returning them to production.
  - iii. Verify the integrity of restored data.
- **F.** Lessons Learned:
  - i. Conduct a post-incident review.
  - ii. Identify areas for improvement and update the IRP.
  - iii. Share lessons learned with the wider team.

**3\. Disaster Recovery Planning**

- **A.** Business Impact Analysis (BIA): How long could you do without this and that?
  - i. Identify **critical systems**, applications, and data.
    - **Isolate business critical machines/network**
  - ii. Determine acceptable downtime for each critical component.
  - iii. Assess potential financial and operational impacts of downtime.
    - Learn more about BIA: <https://www.ready.gov/business/planning/impact-analysis>
    - Creating your own BIA spreadsheet:
    - <https://www.ready.gov/sites/default/files/2020-07/business-impact-analysis-worksheet.pdf>
- **B.** Recovery Strategies:
  - i. Develop strategies for backup and recovery of data and systems.
  - ii. Consider on-premises, cloud-based, or hybrid solutions.
  - iii. Choose recovery time objectives (RTOs) and recovery point objectives (RPOs) that align with your BIA.
- **C.** Testing and Drills:
  - i. Regularly test your DR plan to ensure it's effective and up-to-date.
  - ii. Conduct drills to familiarize staff with procedures.
  - iii. Document and review results to identify areas for improvement.

**4\. CrowdStrike Incident: Key Lessons**

- **A.** Vendor Dependency: Understand your vendors' software, dependencies, and their potential impact on your infrastructure.
- **B.** Change Management: Test all changes thoroughly in a non-production environment before deployment.
- **C.** Offline Recovery: Have offline recovery procedures and backups in place for critical systems and data.
- **D.** Communication: Communicate transparently and promptly with affected users and stakeholders. Be vigilant against phishing and social engineering attacks that may exploit the situation.

**5\. Tools and Resources**

- **A.** Third-Party Auditing Tools:
  - i. CoreView: <https://www.coreview.com/>
  - ii. BetterCloud: <https://www.bettercloud.com/>
  - iii. ManageEngine M365 Manager Plus: <https://www.manageengine.com/microsoft-365-management-reporting/>
  - iv. Netwrix Auditor for Microsoft 365: <https://www.netwrix.com/office_365_auditing.html>
- **B.** Incident Response Platforms:
  - i. PagerDuty: <https://www.pagerduty.com/>
  - ii. Opsgenie: <https://www.atlassian.com/software/opsgenie>
  - iii. Splunk SOAR: <https://www.splunk.com/en_us/software/splunk-security-orchestration-and-automation.html>
  - iv. FireHydrant: <https://firehydrant.io/>
- **C.** SOC 2 Compliance:
  - i. AICPA SOC 2 Guide: <https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2>
  - ii. Compliance Frameworks: Sprinto, Vanta, Drata (see their respective websites)

#### **_Sources_**

1. [zenodo.org/record/7327987/files/Trusted-CI-OT-Solutions-Roadmap.pdf](https://zenodo.org/record/7327987/files/Trusted-CI-OT-Solutions-Roadmap.pdf)