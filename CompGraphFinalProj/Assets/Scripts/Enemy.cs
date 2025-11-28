using UnityEngine;
using UnityEngine.AI;

public class Enemy : MonoBehaviour
{
    [Header("VFX")]
    [SerializeField] private ParticleSystem dieVFX;
    private float maxHp = 100f;
    Transform player;
    NavMeshAgent agent;
    void Start()
    {
        agent = GetComponent<NavMeshAgent>();
        player = FindFirstObjectByType<Player>().transform;
    }
    void Update()
    {
        agent.SetDestination(player.position);
    }
    private void TakeDamage()
    {
        maxHp -= 25f;
        if (maxHp <= 0f)
        {
            ParticleSystem p = Instantiate(dieVFX, transform.position, transform.rotation);
            p.Play();
            gameObject.SetActive(false);
        }
    }
    private void OnCollisionEnter(Collision collision)
    {
        if (collision.gameObject.layer == 7)
        {
            TakeDamage();
        }
    }
}