using System.Collections;
using UnityEngine;
public class Player : MonoBehaviour
{
    [Header("Camera")]
    [SerializeField] private float mouseSense = 120f;
    [SerializeField] private float minAngle = -70f;
    [SerializeField] private float maxAngle = 80f;
    [SerializeField] private Transform cam;

    [Header("Movement")]
    [SerializeField] private float speed = 5f;
    [SerializeField] private float acceleration = 6f;

    [Header("Gun")]
    [SerializeField] private float bulletSpeed = 40f;
    [SerializeField] private float rateOfFire = 300f;
    [SerializeField] private float slideRecoil = 0.05f;
    [SerializeField] private Vector3 defaultPosition;
    [SerializeField] private Transform gun;
    [SerializeField] private Transform bulletSpawn;
    [SerializeField] private Rigidbody bulletPrefab;
    [Header("Bullet Materials")]
    [SerializeField] private Material[] bulletMaterials;
    [Header("VFX")]
    [SerializeField] private ParticleSystem shootVFX;
    [SerializeField] private ParticleSystem endVFX;
    [Header("Enemies")]
    [SerializeField] private GameObject[] enemies;

    private bool end = false;
    private bool canShoot = true;
    private float xrot;
    private float yrot;

    private Vector2 inputDir;
    private Rigidbody rigidBody;

    private Vector3 targetLocalPos;
    private Vector3 currentLocalPos;

    private void Start()
    {
        rigidBody = GetComponent<Rigidbody>();

        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;

        yrot = transform.eulerAngles.y;
        targetLocalPos = defaultPosition;
        currentLocalPos = gun.localPosition;
    }
    private void Update()
    {
        if (end)
        {
            rigidBody.linearVelocity = Vector3.zero;
            return;
        }
        float vertical = Input.GetAxisRaw("Vertical");
        float horizontal = Input.GetAxisRaw("Horizontal");
        inputDir = new Vector2(vertical, horizontal);

        float mouseX = Input.GetAxis("Mouse X");
        float mouseY = Input.GetAxis("Mouse Y");

        xrot -= mouseY * mouseSense * Time.deltaTime;
        yrot += mouseX * mouseSense * Time.deltaTime;

        xrot = Mathf.Clamp(xrot, minAngle, maxAngle);
        cam.localRotation = Quaternion.Euler(xrot, 0f, 0f);
        transform.rotation = Quaternion.Euler(0f, yrot, 0f);

        if (Input.GetKey(KeyCode.Mouse0) && canShoot) Fire();

        currentLocalPos = Vector3.Lerp(currentLocalPos, targetLocalPos, 12f * Time.deltaTime);

        gun.localPosition = currentLocalPos;
        gun.rotation = Quaternion.LookRotation(((cam.position + cam.forward * 200f) - gun.position).normalized);
        targetLocalPos = Vector3.Lerp(targetLocalPos, defaultPosition, 5f * Time.deltaTime);

        int c = 0;
        foreach (var e in enemies)
        {
            if (!e.activeInHierarchy) c++;
        }
        if (c >= enemies.Length)
        {
            ParticleSystem p = Instantiate(endVFX, bulletSpawn.position, bulletSpawn.rotation);
            p.Play();
            end = true;
        }
    }
    private void FixedUpdate()
    {
        Vector3 input = transform.forward * inputDir.x + transform.right * inputDir.y;

        Vector3 desiredVel = input * speed;
        Vector3 velChange = desiredVel - rigidBody.linearVelocity;

        Vector3 force = rigidBody.mass * acceleration * velChange;
        rigidBody.AddForce(force, ForceMode.Force);
    }
    private void Fire()
    {
        ParticleSystem p = Instantiate(shootVFX, bulletSpawn.position, bulletSpawn.rotation);
        p.Play();

        Rigidbody b = Instantiate(bulletPrefab, bulletSpawn.position, bulletSpawn.rotation);
        b.linearVelocity = bulletSpawn.forward * bulletSpeed;

        b.gameObject.GetComponent<MeshRenderer>().material = bulletMaterials[Random.Range(0, bulletMaterials.Length)];

        targetLocalPos += Vector3.back * slideRecoil;

        StartCoroutine(DelayShot());
    }
    private IEnumerator DelayShot()
    {
        canShoot = false;
        float delay = 60f / rateOfFire;
        yield return new WaitForSeconds(delay);

        canShoot = true;
    }
    private void OnTriggerEnter(Collider other)
    {
        if (other.gameObject.layer == 8)
        {
            transform.position = Vector3.zero;
        }
    }
}